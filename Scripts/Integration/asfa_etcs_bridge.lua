-- ASFA-ETCS Integration Bridge for RENFE Serie 256
-- Sistema de integración interna y externa entre ASFA y ETCS
-- Gestiona la comunicación bidireccional entre sistemas de seguridad

local asfa_etcs_bridge = {}

-- Integration modes
asfa_etcs_bridge.MODES = {
    INTERNAL = "INTERNAL",      -- Comunicación interna (cabina)
    EXTERNAL = "EXTERNAL",      -- Conexión externa (aplicaciones)
    HYBRID = "HYBRID"           -- Ambas conexiones activas
}

-- State
asfa_etcs_bridge.state = {
    integration_mode = "HYBRID",
    asfa_system = nil,
    etcs_system = nil,
    
    -- Internal communication
    internal_queue = {},
    internal_buffer_size = 100,
    
    -- External communication
    external_connected = false,
    external_port = 9001,
    external_socket = nil,
    external_buffer = "",
    
    -- Synchronization
    last_sync = 0,
    sync_interval = 0.5,  -- segundos
    
    -- Protocol version
    protocol_version = "1.2.0",
    
    -- Statistics
    messages_sent = 0,
    messages_received = 0,
    sync_errors = 0
}

-- Message Types
asfa_etcs_bridge.MSG_TYPES = {
    -- ASFA messages
    ASFA_SIGNAL_DETECTED = "ASFA_SIGNAL",
    ASFA_ALARM = "ASFA_ALARM",
    ASFA_ACK = "ASFA_ACK",
    ASFA_SPEED_LIMIT = "ASFA_SPEED",
    
    -- ETCS messages
    ETCS_SPEED_PROFILE = "ETCS_PROFILE",
    ETCS_MODE_CHANGE = "ETCS_MODE",
    ETCS_LEVEL_CHANGE = "ETCS_LEVEL",
    ETCS_SSD = "ETCS_SSD",
    ETCS_PERMISSION = "ETCS_PERM",
    
    -- Coordination messages
    CONFLICT_ALERT = "CONFLICT",
    OVERRIDE_REQUEST = "OVERRIDE",
    SYSTEM_STATUS = "STATUS",
    
    -- Control messages
    ACK = "ACK",
    NACK = "NACK",
    HEARTBEAT = "HEARTBEAT"
}

-- Message structure template
function asfa_etcs_bridge:create_message(msg_type, payload, source)
    return {
        type = msg_type,
        source = source or "BRIDGE",
        timestamp = os.time(),
        sequence = self.state.messages_sent + 1,
        payload = payload or {},
        priority = self:calculate_priority(msg_type)
    }
end

-- Initialize bridge
function asfa_etcs_bridge:init(asfa_sys, etcs_sys, mode)
    self.state.asfa_system = asfa_sys
    self.state.etcs_system = etcs_sys
    self.state.integration_mode = mode or "HYBRID"
    
    print("[ASFA-ETCS Bridge] Inicializando puente de integración...")
    print(string.format("[ASFA-ETCS Bridge] Modo: %s", self.state.integration_mode))
    
    if self.state.integration_mode == "EXTERNAL" or self.state.integration_mode == "HYBRID" then
        self:init_external_connection()
    end
    
    return true
end

-- ============= INTERNAL COMMUNICATION =============

function asfa_etcs_bridge:send_internal(msg_type, payload, source)
    if not self.state.asfa_system or not self.state.etcs_system then
        print("[Bridge] Error: Sistemas ASFA/ETCS no inicializados")
        return false
    end
    
    local message = self:create_message(msg_type, payload, source)
    
    -- Add to internal queue
    if #self.state.internal_queue >= self.state.internal_buffer_size then
        print("[Bridge] ⚠️  Buffer interno lleno, descartando mensaje antiguo")
        table.remove(self.state.internal_queue, 1)
    end
    
    table.insert(self.state.internal_queue, message)
    self.state.messages_sent = self.state.messages_sent + 1
    
    print(string.format("[Bridge-Internal] Enviado: %s (seq: %d)", msg_type, message.sequence))
    
    -- Process immediately if priority is high
    if message.priority >= 3 then
        self:process_internal_message(message)
    end
    
    return true
end

function asfa_etcs_bridge:receive_internal()
    if #self.state.internal_queue == 0 then
        return nil
    end
    
    local message = table.remove(self.state.internal_queue, 1)
    self.state.messages_received = self.state.messages_received + 1
    
    -- Process message
    self:process_internal_message(message)
    
    return message
end

function asfa_etcs_bridge:process_internal_message(message)
    if message.type == asfa_etcs_bridge.MSG_TYPES.ASFA_SIGNAL_DETECTED then
        self:handle_asfa_signal(message)
    elseif message.type == asfa_etcs_bridge.MSG_TYPES.ASFA_ALARM then
        self:handle_asfa_alarm(message)
    elseif message.type == asfa_etcs_bridge.MSG_TYPES.ETCS_SPEED_PROFILE then
        self:handle_etcs_profile(message)
    elseif message.type == asfa_etcs_bridge.MSG_TYPES.CONFLICT_ALERT then
        self:handle_conflict(message)
    end
end

function asfa_etcs_bridge:handle_asfa_signal(message)
    local payload = message.payload
    
    print(string.format("[Bridge] ASFA Señal detectada: %s (%.0f Hz)", 
        payload.signal_type, payload.frequency))
    
    -- Communicate to ETCS about speed restrictions
    if payload.speed_limit then
        local etcs_msg = self:create_message(
            asfa_etcs_bridge.MSG_TYPES.ASFA_SPEED_LIMIT,
            {
                speed_limit = payload.speed_limit,
                asfa_source = "ASFA_LINE_SIGNAL"
            },
            "ASFA"
        )
        self:send_internal(etcs_msg.type, etcs_msg.payload, "ASFA")
    end
end

function asfa_etcs_bridge:handle_asfa_alarm(message)
    local payload = message.payload
    
    print(string.format("[Bridge] 🚨 ASFA Alarma: %s", payload.alarm_type))
    
    -- Force ETCS to highest supervision level
    if payload.alarm_type == "RED" then
        local etcs_msg = self:create_message(
            asfa_etcs_bridge.MSG_TYPES.CONFLICT_ALERT,
            {
                severity = "CRITICAL",
                source_system = "ASFA",
                action_required = "EMERGENCY_BRAKE"
            },
            "ASFA"
        )
        self:send_internal(etcs_msg.type, etcs_msg.payload, "ASFA")
    end
end

function asfa_etcs_bridge:handle_etcs_profile(message)
    local payload = message.payload
    
    print(string.format("[Bridge] ETCS Perfil de velocidad recibido: Max %d km/h", 
        payload.max_speed))
    
    -- Validate against ASFA limits
    self:validate_speed_consistency(payload.max_speed)
end

function asfa_etcs_bridge:handle_conflict(message)
    local payload = message.payload
    
    print(string.format("[Bridge] ⚠️  CONFLICTO DETECTADO: %s", payload.source_system))
    
    -- Log conflict
    self:log_conflict(message)
    
    -- Take conservative action: apply lowest restriction
    if payload.action_required == "EMERGENCY_BRAKE" then
        print("[Bridge] Activando frenado de emergencia")
    elseif payload.action_required == "SERVICE_BRAKE" then
        print("[Bridge] Activando frenado de servicio")
    end
end

-- ============= SPEED COORDINATION =============

function asfa_etcs_bridge:validate_speed_consistency(etcs_speed_limit)
    if not self.state.asfa_system then
        return true
    end
    
    local asfa_status = self.state.asfa_system:get_status()
    local asfa_limit = asfa_status.speed_limit
    
    -- Check if there's significant difference
    if math.abs(etcs_speed_limit - asfa_limit) > 10 then
        print(string.format("[Bridge] ⚠️  INCONSISTENCIA: ETCS=%d km/h, ASFA=%d km/h",
            etcs_speed_limit, asfa_limit))
        
        -- Take most conservative (lowest) speed
        local conservative_speed = math.min(etcs_speed_limit, asfa_limit)
        
        local conflict_msg = self:create_message(
            asfa_etcs_bridge.MSG_TYPES.CONFLICT_ALERT,
            {
                severity = "WARNING",
                etcs_speed = etcs_speed_limit,
                asfa_speed = asfa_limit,
                adopted_speed = conservative_speed
            },
            "BRIDGE"
        )
        
        self:send_internal(conflict_msg.type, conflict_msg.payload, "BRIDGE")
        
        return false
    end
    
    return true
end

-- ============= EXTERNAL COMMUNICATION =============

function asfa_etcs_bridge:init_external_connection()
    print(string.format("[Bridge-External] Inicializando conexión externa en puerto %d",
        self.state.external_port))
    
    -- In a real implementation, this would create a socket
    -- For simulation, we'll use a message queue
    self.state.external_connected = true
    print("[Bridge-External] ✓ Conexión simulada establecida")
    
    return true
end

function asfa_etcs_bridge:send_external(message)
    if not self.state.external_connected then
        print("[Bridge-External] Error: No hay conexión externa")
        return false
    end
    
    -- Serialize message to JSON/Protocol
    local serialized = self:serialize_message(message)
    
    -- In real implementation, send via socket
    print(string.format("[Bridge-External → APP] %s", serialized))
    
    return true
end

function asfa_etcs_bridge:receive_external(json_data)
    if not json_data then
        return nil
    end
    
    -- Deserialize incoming data
    local message = self:deserialize_message(json_data)
    
    if message then
        print(string.format("[Bridge-External ← APP] Recibido: %s", message.type))
        self:process_external_message(message)
        return message
    end
    
    return nil
end

function asfa_etcs_bridge:process_external_message(message)
    if message.type == "QUERY_STATUS" then
        self:handle_status_query(message)
    elseif message.type == "SET_PARAMETER" then
        self:handle_parameter_change(message)
    elseif message.type == "EXTERNAL_SIGNAL" then
        self:handle_external_signal(message)
    end
end

function asfa_etcs_bridge:handle_status_query(message)
    local status = {
        timestamp = os.time(),
        asfa_status = self.state.asfa_system:get_status(),
        etcs_status = self.state.etcs_system:get_status(),
        bridge_statistics = self:get_statistics()
    }
    
    self:send_external(self:create_message("STATUS_RESPONSE", status, "BRIDGE"))
end

function asfa_etcs_bridge:handle_parameter_change(message)
    local param = message.payload.parameter
    local value = message.payload.value
    
    print(string.format("[Bridge-External] Cambio de parámetro: %s = %s", param, value))
    
    if param == "asfa_enabled" then
        self.state.asfa_system:set_config("enabled", value)
    elseif param == "etcs_level" then
        self.state.etcs_system:transition_level(value)
    end
    
    self:send_external(self:create_message("PARAMETER_ACK", {param = param}, "BRIDGE"))
end

function asfa_etcs_bridge:handle_external_signal(message)
    local signal = message.payload
    
    print(string.format("[Bridge-External] Señal externa: Tipo=%s, Freq=%.0f Hz",
        signal.signal_type, signal.frequency))
    
    -- Inject signal into ASFA system
    if self.state.asfa_system then
        self.state.asfa_system:detect_signal(signal.frequency)
    end
    
    self:send_external(self:create_message("SIGNAL_ACK", {id = signal.id}, "BRIDGE"))
end

-- ============= SYNCHRONIZATION =============

function asfa_etcs_bridge:update(dt)
    -- Process internal queue
    while #self.state.internal_queue > 0 do
        self:receive_internal()
    end
    
    -- Periodic synchronization
    self.state.last_sync = self.state.last_sync + dt
    if self.state.last_sync >= self.state.sync_interval then
        self:synchronize_systems()
        self.state.last_sync = 0
    end
    
    -- Send heartbeat externally
    if self.state.external_connected then
        self:send_heartbeat()
    end
end

function asfa_etcs_bridge:synchronize_systems()
    if not self.state.asfa_system or not self.state.etcs_system then
        return
    end
    
    -- Get status from both systems
    local asfa_status = self.state.asfa_system:get_status()
    local etcs_status = self.state.etcs_system:get_status()
    
    -- Synchronize speed limits
    if asfa_status.speed_limit ~= etcs_status.ceiling_speed then
        self:validate_speed_consistency(etcs_status.ceiling_speed)
    end
    
    -- Check for alarms
    if asfa_status.emergency_brake_armed and not etcs_status.emergency_stop then
        print("[Bridge] Sincronizando: Activando frenado de emergencia en ETCS")
    end
    
    -- Send heartbeat to external systems
    if self.state.external_connected then
        self:send_external(self:create_message(
            asfa_etcs_bridge.MSG_TYPES.HEARTBEAT,
            {
                asfa_ok = asfa_status.system_active,
                etcs_ok = etcs_status.mode ~= nil,
                sync_count = self.state.messages_sent
            },
            "BRIDGE"
        ))
    end
end

function asfa_etcs_bridge:send_heartbeat()
    local heartbeat = self:create_message(
        asfa_etcs_bridge.MSG_TYPES.HEARTBEAT,
        {
            bridge_version = self.state.protocol_version,
            messages_sent = self.state.messages_sent,
            messages_received = self.state.messages_received,
            sync_errors = self.state.sync_errors
        },
        "BRIDGE"
    )
    
    self:send_external(heartbeat)
end

-- ============= UTILITIES =============

function asfa_etcs_bridge:calculate_priority(msg_type)
    -- Priority levels: 1 (low) to 5 (critical)
    if msg_type == asfa_etcs_bridge.MSG_TYPES.ASFA_ALARM or
       msg_type == asfa_etcs_bridge.MSG_TYPES.CONFLICT_ALERT then
        return 5  -- Critical
    elseif msg_type == asfa_etcs_bridge.MSG_TYPES.ETCS_SSD or
           msg_type == asfa_etcs_bridge.MSG_TYPES.ASFA_SPEED_LIMIT then
        return 3  -- High
    else
        return 1  -- Low
    end
end

function asfa_etcs_bridge:serialize_message(message)
    -- Simple JSON serialization
    local json_parts = {}
    table.insert(json_parts, string.format('{"type":"%s"', message.type))
    table.insert(json_parts, string.format(',"source":"%s"', message.source))
    table.insert(json_parts, string.format(',"timestamp":%d', message.timestamp))
    
    if message.payload then
        table.insert(json_parts, ',"payload":{')
        local payload_parts = {}
        for k, v in pairs(message.payload) do
            if type(v) == "string" then
                table.insert(payload_parts, string.format('"%s":"%s"', k, v))
            else
                table.insert(payload_parts, string.format('"%s":%s', k, tostring(v)))
            end
        end
        table.insert(json_parts, table.concat(payload_parts, ","))
        table.insert(json_parts, '}')
    end
    
    table.insert(json_parts, '}')
    return table.concat(json_parts)
end

function asfa_etcs_bridge:deserialize_message(json_string)
    -- Simple JSON parsing
    -- In production, use a proper JSON library
    local message = {}
    
    -- Extract type
    local type_match = json_string:match('"type":"([^"]+)"')
    if type_match then
        message.type = type_match
    end
    
    -- Extract payload
    local payload_match = json_string:match('"payload":({[^}]+})')
    if payload_match then
        message.payload = {}
        -- Simple parsing of payload
        for key, value in payload_match:gmatch('"([^"]+)":([^,}]+)') do
            message.payload[key] = tonumber(value) or value
        end
    end
    
    return message.type and message or nil
end

function asfa_etcs_bridge:log_conflict(message)
    print(string.format("[Bridge-Log] CONFLICTO: %s | Severidad: %s",
        message.payload.source_system,
        message.payload.severity))
    
    self.state.sync_errors = self.state.sync_errors + 1
end

function asfa_etcs_bridge:get_statistics()
    return {
        protocol_version = self.state.protocol_version,
        integration_mode = self.state.integration_mode,
        messages_sent = self.state.messages_sent,
        messages_received = self.state.messages_received,
        sync_errors = self.state.sync_errors,
        queue_size = #self.state.internal_queue,
        external_connected = self.state.external_connected
    }
end

function asfa_etcs_bridge:display_status()
    print("\n=== ASFA-ETCS BRIDGE STATUS ===")
    print(string.format("Modo: %s", self.state.integration_mode))
    print(string.format("Mensajes enviados: %d", self.state.messages_sent))
    print(string.format("Mensajes recibidos: %d", self.state.messages_received))
    print(string.format("Errores de sincronización: %d", self.state.sync_errors))
    print(string.format("Cola interna: %d mensajes", #self.state.internal_queue))
    print(string.format("Conexión externa: %s", self.state.external_connected and "✓ ACTIVA" or "✗ INACTIVA"))
    print("================================\n")
end

function asfa_etcs_bridge:reset()
    self.state.internal_queue = {}
    self.state.messages_sent = 0
    self.state.messages_received = 0
    self.state.sync_errors = 0
    self.state.last_sync = 0
    print("[Bridge] Sistema reiniciado")
    return true
end

return asfa_etcs_bridge

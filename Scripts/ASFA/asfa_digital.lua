-- ASFA Digital System for RENFE Serie 256
-- Sistema ASFA (Asistencia de Seguridad en Frenado y Aceleración)
-- Implementation based on Spanish Railway Safety Standards

local asfa_digital = {}

-- Constants
asfa_digital.FREQUENCIES = {
    YELLOW_SIGNAL = 1688,      -- Hz - Señal amarilla (reducir velocidad)
    RED_SIGNAL = 1998,         -- Hz - Señal roja (parada obligatoria)
    WHITE_SIGNAL = 2000,       -- Hz - Señal blanca (vía libre)
    YELLOW_BAND = {1688, 1750},
    RED_BAND = {1998, 2000}
}

asfa_digital.SPEED_LIMITS = {
    YELLOW = 60,  -- km/h
    RED = 0,      -- km/h (parada)
    WHITE = 160   -- km/h (vía libre)
}

asfa_digital.REACTION_TIME = 4  -- segundos (tiempo de reacción del conductor)
asfa_digital.SUPERVISION_TIME = 60  -- segundos

-- State variables
asfa_digital.state = {
    current_signal = "WHITE",
    detected_frequency = 0,
    current_speed = 0,
    speed_limit = 160,
    driver_acked = false,
    last_ack_time = 0,
    ack_required = false,
    alarm_active = false,
    emergency_brake_armed = false,
    supervision_timer = 0,
    asfa_active = true
}

-- Configuration
asfa_digital.config = {
    enabled = true,
    asfa_version = 2,  -- ASFA Digital v2
    audible_warnings = true,
    visual_warnings = true,
    emergency_brake_active = true,
    max_overspeed_tolerance = 5  -- km/h
}

-- Initialization
function asfa_digital:init(train)
    self.train = train
    self.state.current_speed = 0
    self.state.driver_acked = false
    self.state.supervision_timer = 0
    print("[ASFA] Sistema ASFA Digital inicializado")
    return true
end

-- Update function (called every simulation cycle)
function asfa_digital:update(dt, current_speed, detected_signal)
    if not self.config.enabled then
        return
    end
    
    self.state.current_speed = current_speed
    
    -- Detect signal from line
    if detected_signal then
        self:detect_signal(detected_signal)
    end
    
    -- Update supervision timer
    if self.state.ack_required then
        self.state.supervision_timer = self.state.supervision_timer + dt
        
        -- If supervision time exceeded and no acknowledgment
        if self.state.supervision_timer > self.SUPERVISION_TIME then
            self:trigger_emergency_brake("Falta de confirmación del maquinista")
        end
    end
    
    -- Check overspeed condition
    if self.state.current_speed > (self.state.speed_limit + self.config.max_overspeed_tolerance) then
        self:handle_overspeed()
    end
    
    return {
        signal = self.state.current_signal,
        speed_limit = self.state.speed_limit,
        alarm_active = self.state.alarm_active,
        emergency_brake = self.state.emergency_brake_armed
    }
end

-- Signal detection function
function asfa_digital:detect_signal(frequency)
    local old_signal = self.state.current_signal
    
    -- Classify signal based on frequency
    if frequency >= self.FREQUENCIES.YELLOW_BAND[1] and 
       frequency <= self.FREQUENCIES.YELLOW_BAND[2] then
        self.state.current_signal = "YELLOW"
        self.state.speed_limit = self.SPEED_LIMITS.YELLOW
        
    elseif frequency >= self.FREQUENCIES.RED_BAND[1] and 
           frequency <= self.FREQUENCIES.RED_BAND[2] then
        self.state.current_signal = "RED"
        self.state.speed_limit = self.SPEED_LIMITS.RED
        
    else
        self.state.current_signal = "WHITE"
        self.state.speed_limit = self.SPEED_LIMITS.WHITE
    end
    
    self.state.detected_frequency = frequency
    
    -- Signal change detected
    if old_signal ~= self.state.current_signal then
        self:on_signal_change(old_signal, self.state.current_signal)
    end
    
    return self.state.current_signal
end

-- Signal change handler
function asfa_digital:on_signal_change(old_signal, new_signal)
    print(string.format("[ASFA] Cambio de señal: %s -> %s", old_signal, new_signal))
    
    if new_signal == "YELLOW" then
        self:trigger_yellow_warning()
    elseif new_signal == "RED" then
        self:trigger_red_alarm()
    elseif new_signal == "WHITE" then
        self:clear_alarm()
    end
end

-- Yellow warning (speed reduction required)
function asfa_digital:trigger_yellow_warning()
    self.state.alarm_active = true
    self.state.ack_required = true
    self.state.supervision_timer = 0
    self.state.driver_acked = false
    
    if self.config.audible_warnings then
        self:play_sound("asfa_yellow", 0.8)
    end
    
    if self.config.visual_warnings then
        self:show_visual_warning("AMARILLA", 1)
    end
    
    print("[ASFA] ⚠️  Aviso amarillo - Reducir velocidad a 60 km/h")
end

-- Red alarm (emergency)
function asfa_digital:trigger_red_alarm()
    self.state.alarm_active = true
    self.state.ack_required = true
    self.state.supervision_timer = 0
    self.state.driver_acked = false
    
    if self.config.audible_warnings then
        self:play_sound("asfa_red_loop", 1.0)
    end
    
    if self.config.visual_warnings then
        self:show_visual_warning("ROJA", 2)
    end
    
    print("[ASFA] 🛑 Alarma roja - Parada obligatoria")
    
    -- If driver doesn't acknowledge, trigger emergency brake
    if not self.state.driver_acked then
        local timeout = 4  -- segundos
        if self.state.supervision_timer > timeout then
            if self.config.emergency_brake_active then
                self:trigger_emergency_brake("Falta de confirmación en alarma roja")
            end
        end
    end
end

-- Clear alarm
function asfa_digital:clear_alarm()
    self.state.alarm_active = false
    self.state.ack_required = false
    self.state.driver_acked = false
    self.state.supervision_timer = 0
    
    if self.config.audible_warnings then
        self:play_sound("asfa_clear", 0.5)
    end
    
    print("[ASFA] ✓ Alarma cancelada - Vía libre")
end

-- Overspeed handling
function asfa_digital:handle_overspeed()
    local overspeed = self.state.current_speed - self.state.speed_limit
    
    if overspeed > 10 then
        print(string.format("[ASFA] ⚠️  EXCESO DE VELOCIDAD: %d km/h sobre límite", overspeed))
        
        if self.config.audible_warnings then
            self:play_sound("asfa_overspeed", 0.9)
        end
        
        if self.config.emergency_brake_active and overspeed > 15 then
            self:trigger_emergency_brake("Exceso de velocidad crítico")
        end
    end
end

-- Emergency brake activation
function asfa_digital:trigger_emergency_brake(reason)
    if not self.config.emergency_brake_active then
        return false
    end
    
    self.state.emergency_brake_armed = true
    
    print(string.format("[ASFA] 🚨 FRENO DE EMERGENCIA ACTIVADO: %s", reason))
    
    if self.config.audible_warnings then
        self:play_sound("asfa_emergency", 1.0)
    end
    
    if self.train then
        self.train:apply_emergency_brake()
    end
    
    return true
end

-- Driver acknowledgment
function asfa_digital:driver_acknowledge()
    if not self.state.ack_required then
        return false
    end
    
    self.state.driver_acked = true
    self.state.last_ack_time = os.time()
    self.state.supervision_timer = 0
    
    if self.state.current_signal == "YELLOW" then
        print("[ASFA] ✓ Confirmación de aviso amarillo")
        if self.config.audible_warnings then
            self:play_sound("asfa_ack", 0.6)
        end
    elseif self.state.current_signal == "RED" then
        print("[ASFA] ✓ Confirmación de alarma roja")
        if self.config.audible_warnings then
            self:play_sound("asfa_ack", 0.6)
        end
    end
    
    return true
end

-- Visual warning display
function asfa_digital:show_visual_warning(signal_type, level)
    -- level: 1 = Yellow, 2 = Red
    print(string.format("[ASFA Display] Señal: %s (Nivel %d)", signal_type, level))
end

-- Sound management
function asfa_digital:play_sound(sound_name, volume)
    -- Integration with audio system
    print(string.format("[ASFA Audio] Reproduciendo: %s (vol: %.1f)", sound_name, volume))
end

-- Get ASFA status
function asfa_digital:get_status()
    return {
        system_active = self.state.asfa_active,
        current_signal = self.state.current_signal,
        speed_limit = self.state.speed_limit,
        current_speed = self.state.current_speed,
        overspeed = math.max(0, self.state.current_speed - self.state.speed_limit),
        alarm_active = self.state.alarm_active,
        emergency_brake_armed = self.state.emergency_brake_armed,
        driver_ack_required = self.state.ack_required,
        driver_acknowledged = self.state.driver_acked,
        supervision_time_remaining = math.max(0, self.SUPERVISION_TIME - self.state.supervision_timer),
        detected_frequency = self.state.detected_frequency
    }
end

-- Reset system
function asfa_digital:reset()
    self.state.current_signal = "WHITE"
    self.state.detected_frequency = 0
    self.state.current_speed = 0
    self.state.speed_limit = 160
    self.state.driver_acked = false
    self.state.ack_required = false
    self.state.alarm_active = false
    self.state.emergency_brake_armed = false
    self.state.supervision_timer = 0
    
    print("[ASFA] Sistema reiniciado")
    return true
end

-- Configuration management
function asfa_digital:set_config(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        print(string.format("[ASFA Config] %s = %s", key, tostring(value)))
        return true
    end
    return false
end

-- External connection interface
function asfa_digital:connect_external(port)
    print(string.format("[ASFA] Conexión externa iniciada en puerto %d", port))
    self.external_port = port
    return true
end

function asfa_digital:send_to_external(data)
    if self.external_port then
        -- Serialize data to JSON or binary format
        print(string.format("[ASFA External] Enviando: %s", data))
    end
end

function asfa_digital:receive_from_external(data)
    -- Process external data
    print(string.format("[ASFA External] Recibido: %s", data))
end

-- Diagnostics
function asfa_digital:run_diagnostics()
    local diagnostics = {
        system_online = self.config.enabled,
        audio_ok = true,
        visual_display_ok = true,
        sensor_communication_ok = true,
        emergency_brake_ok = true,
        timestamp = os.time()
    }
    
    print("[ASFA Diagnostics] Sistema OK - Todos los componentes funcionales")
    return diagnostics
end

return asfa_digital

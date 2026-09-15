-- RENFE Serie 256 Main Controller
-- Controlador principal que coordina todos los sistemas

local main_controller = {}

-- Cargar módulos
local asfa = require("Scripts/ASFA/asfa_digital")
local etcs = require("Scripts/ETCS/etcs_multilevel")
local bridge = require("Scripts/Integration/asfa_etcs_bridge")

-- Estado del controlador
main_controller.state = {
    initialized = false,
    train = nil,
    simulation_time = 0,
    frame_count = 0,
    is_running = false
}

-- Inicialización
function main_controller:init(train_obj)
    print("\n" .. string.rep("=", 60))
    print("RENFE SERIE 256 - SISTEMA DE CONTROL INTEGRADO")
    print("ASFA Digital + ETCS Multi-Nivel")
    print(string.rep("=", 60) .. "\n")
    
    self.state.train = train_obj
    
    -- Inicializar ASFA
    print("[INIT] Inicializando ASFA Digital...")
    asfa:init(train_obj)
    
    -- Inicializar ETCS Level 2
    print("[INIT] Inicializando ETCS Level 2...")
    etcs:init(train_obj, 12)  -- Level 2
    
    -- Inicializar Puente de Integración
    print("[INIT] Inicializando Puente ASFA-ETCS...")
    bridge:init(asfa, etcs, "HYBRID")
    
    self.state.initialized = true
    self.state.is_running = true
    
    print("\n[INIT] ✓ Sistema completamente inicializado")
    print("[INIT] Modo: HYBRID (Interno + Externo)")
    print("[INIT] Puerto externo: 9001\n")
    
    return true
end

-- Loop de actualización principal
function main_controller:update(dt)
    if not self.state.initialized or not self.state.is_running then
        return nil
    end
    
    self.state.simulation_time = self.state.simulation_time + dt
    self.state.frame_count = self.state.frame_count + 1
    
    -- Obtener datos del tren
    local speed = self.state.train:get_speed() or 0
    local position = self.state.train:get_position() or 0
    
    -- Simular detección de señal ASFA cada cierto tiempo
    local signal_freq = self:simulate_signal_detection(position)
    
    -- Actualizar ASFA
    asfa:update(dt, speed, signal_freq)
    
    -- Actualizar ETCS
    etcs:update(dt, speed, position)
    
    -- Sincronizar sistemas a través del puente
    bridge:update(dt)
    
    -- Obtener estado combinado
    local combined_status = self:get_combined_status()
    
    -- Mostrar información periodicamente (cada 5 segundos simulados)
    if math.floor(self.state.simulation_time) % 5 == 0 and self.state.frame_count % 100 == 0 then
        self:log_status(combined_status)
    end
    
    return combined_status
end

-- Simular detección de señales
function main_controller:simulate_signal_detection(position)
    -- Simular señales cada 5 km de línea
    local signal_points = {
        {pos = 0, freq = 2000, type = "WHITE"},      -- Vía libre
        {pos = 5000, freq = 1688, type = "YELLOW"},  -- Reducir velocidad
        {pos = 10000, freq = 1998, type = "RED"},    -- Parada
        {pos = 15000, freq = 2000, type = "WHITE"},  -- Vía libre
    }
    
    for _, point in ipairs(signal_points) do
        if math.abs(position - point.pos) < 100 then
            return point.freq
        end
    end
    
    return nil
end

-- Obtener estado combinado de todos los sistemas
function main_controller:get_combined_status()
    return {
        asfa = asfa:get_status(),
        etcs = etcs:get_status(),
        bridge_stats = bridge:get_statistics(),
        simulation_time = self.state.simulation_time,
        frame = self.state.frame_count
    }
end

-- Registrar estado en consola
function main_controller:log_status(status)
    print(string.format("\n[LOG] Tiempo simulado: %.1f s | Frame: %d", 
        self.state.simulation_time, self.state.frame_count))
    
    if status.asfa then
        print(string.format("  ASFA: Señal=%s, Límite=%d km/h, Vel=%d km/h",
            status.asfa.current_signal,
            status.asfa.speed_limit,
            status.asfa.current_speed))
    end
    
    if status.etcs then
        print(string.format("  ETCS: Nivel=%s, Modo=%s, Límite=%d km/h, Vel=%d km/h",
            status.etcs.level_name,
            status.etcs.mode,
            status.etcs.ceiling_speed,
            status.etcs.current_speed))
    end
end

-- Manejo de entrada del usuario (teclas presionadas)
function main_controller:on_key_press(key)
    if key == "A" then
        -- Confirmar alarma ASFA
        asfa:driver_acknowledge()
        print("[INPUT] Confirmación ASFA ejecutada")
        
    elseif key == "E" then
        -- Mostrar DMI ETCS
        etcs:display_dmi()
        
    elseif key == "B" then
        -- Mostrar estado del puente
        bridge:display_status()
        
    elseif key == "D" then
        -- Ejecutar diagnósticos
        local diag = asfa:run_diagnostics()
        print("[DIAGNOSTICS]")
        for k, v in pairs(diag) do
            print(string.format("  %s: %s", k, tostring(v)))
        end
        
    elseif key == "R" then
        -- Reiniciar sistemas
        print("[ACTION] Reiniciando sistemas...")
        asfa:reset()
        etcs:reset()
        bridge:reset()
        print("[ACTION] Sistemas reiniciados")
    end
end

-- Manejo de eventos
function main_controller:on_event(event_type, event_data)
    if event_type == "ASFA_ALARM" then
        print(string.format("[EVENT] Alarma ASFA: %s", event_data.alarm_type))
        
    elseif event_type == "ETCS_MODE_CHANGE" then
        print(string.format("[EVENT] Cambio de modo ETCS: %s -> %s",
            event_data.old_mode, event_data.new_mode))
            
    elseif event_type == "CONFLICT" then
        print(string.format("[EVENT] CONFLICTO DETECTADO: %s",
            event_data.description))
    end
end

-- Shutdown
function main_controller:shutdown()
    print("\n[SHUTDOWN] Deteniendo sistemas...")
    self.state.is_running = false
    asfa:reset()
    etcs:reset()
    bridge:reset()
    print("[SHUTDOWN] Sistema detenido correctamente\n")
    return true
end

return main_controller

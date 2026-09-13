-- ETCS Multi-Level System for RENFE Serie 256
-- European Train Control System (ETCS) - All Levels + LZB Support
-- Niveles: OFF, STM (LZB), Level 0, Level 1, Level 2, Level 3

local etcs = {}

-- ETCS Levels
etcs.LEVELS = {
    OFF = 0,
    STM_LZB = 1,    -- Linien-Zug-Beeinflussung (Legacy German system)
    LEVEL_0 = 10,   -- Odometer-based
    LEVEL_1 = 11,   -- Eurobalise equipped
    LEVEL_2 = 12,   -- Eurobalise + GSM-R
    LEVEL_3 = 13    -- CBTC without line-side equipment
}

etcs.LEVEL_NAMES = {
    [etcs.LEVELS.OFF] = "OFF",
    [etcs.LEVELS.STM_LZB] = "STM LZB",
    [etcs.LEVELS.LEVEL_0] = "Level 0",
    [etcs.LEVELS.LEVEL_1] = "Level 1",
    [etcs.LEVELS.LEVEL_2] = "Level 2",
    [etcs.LEVELS.LEVEL_3] = "Level 3"
}

-- Operating Modes
etcs.MODES = {
    SB = "SB",      -- Stand By
    OS = "OS",      -- On Sight
    LS = "LS",      -- Limited Supervision
    PS = "PS",      -- Partial Supervision
    FS = "FS",      -- Full Supervision
    SH = "SH",      -- Shunting
    UN = "UN"       -- Unfitted
}

-- System State
etcs.state = {
    current_level = 12,         -- Level 2 por defecto
    current_mode = "FS",        -- Full Supervision
    allowed_speed = 160,        -- km/h
    ceiling_speed = 160,        -- km/h
    current_speed = 0,          -- km/h
    target_speed = 160,         -- km/h
    permission_distance = 0,    -- metros
    
    -- SSD (Speed Supervision Data)
    ssd_active = false,
    ssd_curve = {},
    
    -- Eurobalise Communication
    last_balise_id = 0,
    balise_data = {},
    
    -- GSM-R Communication (Level 2)
    gsm_r_connected = true,
    rbc_id = "RBC_MADRID_01",
    last_rbc_message = 0,
    
    -- LZB Data (STM Mode)
    lzb_frequency = 81.81,      -- MHz (German standard)
    lzb_data_rate = 600,        -- bps
    lzb_pulse_pattern = {},
    
    -- DMI (Driver Machine Interface)
    dmi_active = true,
    dmi_brightness = 100,
    dmi_messages = {},
    
    -- Safety Data
    emergency_stop_active = false,
    sb_active = false,          -- Service Brake
    eb_active = false,          -- Emergency Brake
    
    -- Mode transition
    mode_transition_in_progress = false,
    mode_transition_target = "FS"
}

-- Configuration
etcs.config = {
    system_version = "3.6.0",
    equipped_levels = {
        [etcs.LEVELS.STM_LZB] = true,
        [etcs.LEVELS.LEVEL_0] = true,
        [etcs.LEVELS.LEVEL_1] = true,
        [etcs.LEVELS.LEVEL_2] = true,
        [etcs.LEVELS.LEVEL_3] = false  -- Not equipped in this implementation
    },
    
    -- Speed monitoring tolerance
    speed_tolerance_percent = 5,  -- 5% of ceiling speed
    
    -- Supervision thresholds
    warning_threshold = 0.95,   -- 95% of ceiling speed triggers warning
    intervention_threshold = 1.0 -- 100% triggers intervention
}

-- Initialize ETCS system
function etcs:init(train, initial_level)
    self.train = train
    self.state.current_level = initial_level or etcs.LEVELS.LEVEL_2
    self.state.current_speed = 0
    self.state.allowed_speed = 160
    self.state.ceiling_speed = 160
    
    print(string.format("[ETCS] Sistema ETCS inicializado en %s", 
        etcs.LEVEL_NAMES[self.state.current_level]))
    
    if self.state.current_level == etcs.LEVELS.LEVEL_2 then
        self:init_gsm_r_connection()
    elseif self.state.current_level == etcs.LEVELS.STM_LZB then
        self:init_lzb_connection()
    end
    
    return true
end

-- Main update function
function etcs:update(dt, current_speed, position)
    if self.state.current_level == etcs.LEVELS.OFF then
        return nil
    end
    
    self.state.current_speed = current_speed
    
    -- Update based on current level
    if self.state.current_level == etcs.LEVELS.STM_LZB then
        self:update_lzb(dt, current_speed, position)
    elseif self.state.current_level == etcs.LEVELS.LEVEL_0 then
        self:update_level_0(dt, current_speed)
    elseif self.state.current_level == etcs.LEVELS.LEVEL_1 then
        self:update_level_1(dt, current_speed)
    elseif self.state.current_level == etcs.LEVELS.LEVEL_2 then
        self:update_level_2(dt, current_speed, position)
    elseif self.state.current_level == etcs.LEVELS.LEVEL_3 then
        self:update_level_3(dt, current_speed, position)
    end
    
    -- Update SSD if active
    if self.state.ssd_active then
        self:update_ssd(dt)
    end
    
    -- Check speed supervision
    self:supervise_speed()
    
    -- Update DMI
    self:update_dmi()
    
    return self:get_status()
end

-- ============= LZB (Linien-Zug-Beeinflussung) Implementation =============

function etcs:init_lzb_connection()
    print("[ETCS-LZB] Inicializando conexión LZB...")
    print(string.format("[ETCS-LZB] Frecuencia: %.2f MHz", self.state.lzb_frequency))
    print(string.format("[ETCS-LZB] Velocidad de datos: %d bps", self.state.lzb_data_rate))
    
    self.state.current_mode = "FS"
    return true
end

function etcs:update_lzb(dt, current_speed, position)
    -- LZB pulse pattern detection (1688 Hz carrier frequency)
    local lzb_carrier = 1688
    
    -- Simulate pulse decoding
    local pulse_data = self:decode_lzb_pulses()
    
    if pulse_data then
        self.state.allowed_speed = pulse_data.speed_limit or 160
        self.state.target_speed = pulse_data.target_speed or 160
        
        -- LZB specific: Announcements (Ansagen)
        if pulse_data.announcement then
            self:process_lzb_announcement(pulse_data.announcement)
        end
    end
    
    -- Monitor for line-side repeaters
    self:check_lzb_repeaters(position)
end

function etcs:decode_lzb_pulses()
    -- Simulated LZB pulse decoding
    -- Real LZB: trains receive pulses via overhead wire at 1688 Hz
    return {
        speed_limit = self.state.allowed_speed,
        target_speed = self.state.target_speed,
        announcement = nil
    }
end

function etcs:check_lzb_repeaters(position)
    -- LZB repeaters transmit every 100-300m along the line
    -- Check proximity to simulated repeater
    local repeater_distance = position % 250  -- Simulated repeaters every 250m
    
    if repeater_distance < 10 then
        print(string.format("[ETCS-LZB] Repetidor cercano (%.1f m)", repeater_distance))
    end
end

function etcs:process_lzb_announcement(announcement)
    print(string.format("[ETCS-LZB] Anuncio: %s", announcement))
    self:add_dmi_message(string.format("LZB Ansage: %s", announcement), "info")
end

-- ============= LEVEL 0 Implementation (Odometer-based) =============

function etcs:update_level_0(dt, current_speed)
    -- Level 0: No line-side equipment, speed monitoring via odometer
    -- Used as fallback or in non-equipped lines
    
    if self.state.current_mode == "UN" then
        self.state.current_mode = "OS"  -- Switch to On Sight
    end
    
    -- Speed restriction based on track data
    self.state.allowed_speed = self:get_track_speed_limit()
end

-- ============= LEVEL 1 Implementation (Eurobalise-based) =============

function etcs:update_level_1(dt, current_speed)
    -- Level 1: Discrete Eurobalise equipment
    -- Balises transmit train data via radio
    
    -- Check for Eurobalise encounters
    self:check_eurobalises()
    
    -- Transition to FS mode (Full Supervision)
    if self.state.current_mode == "SB" then
        self.state.current_mode = "LS"  -- Limited Supervision
    elseif self.state.current_mode == "LS" then
        self.state.current_mode = "FS"  -- Full Supervision
    end
    
    -- Update from balise data
    if self.state.last_balise_id > 0 then
        self:process_balise_data()
    end
end

function etcs:check_eurobalises()
    -- Eurobalises at signals, junctions, speed change points
    -- Transmit train data (TIU: Train Interface Unit) to on-board equipment
    
    -- Simulated: Check if near known balise location
    local balise_found = math.random(1, 100) < 5  -- 5% chance of encountering balise per update
    
    if balise_found then
        self.state.last_balise_id = math.random(1000, 9999)
        print(string.format("[ETCS-L1] Eurobalisa detectada: ID %d", self.state.last_balise_id))
        
        -- Request balise data from line equipment
        self:request_balise_data(self.state.last_balise_id)
    end
end

function etcs:request_balise_data(balise_id)
    -- Simulated balise data structure
    self.state.balise_data = {
        balise_id = balise_id,
        msg_type = "LINKING",  -- Linking message (speed changes, route info)
        speed_restriction = 160,
        distance_to_restriction = 1000,  -- meters
        level = etcs.LEVELS.LEVEL_1,
        nid_c = 1  -- Country ID (1=Spain)
    }
end

function etcs:process_balise_data()
    if self.state.balise_data.speed_restriction then
        self.state.allowed_speed = self.state.balise_data.speed_restriction
        self.state.ceiling_speed = self.state.balise_data.speed_restriction
    end
    
    if self.state.balise_data.distance_to_restriction then
        self.state.permission_distance = self.state.balise_data.distance_to_restriction
    end
end

-- ============= LEVEL 2 Implementation (GSM-R based) =============

function etcs:init_gsm_r_connection()
    print("[ETCS-L2] Inicializando conexión GSM-R...")
    print(string.format("[ETCS-L2] Conectando con RBC: %s", self.state.rbc_id))
    
    self.state.gsm_r_connected = true
    self.state.current_mode = "SB"  -- Start in Stand By
    
    -- Request authorization from RBC
    self:request_rbc_authorization()
end

function etcs:update_level_2(dt, current_speed, position)
    -- Level 2: Continuous communication via GSM-R with RBC (Radio Block Center)
    
    -- Check GSM-R link status
    if not self.state.gsm_r_connected then
        self:on_gsm_r_loss()
        return
    end
    
    -- Send position report to RBC periodically
    self.state.last_rbc_message = self.state.last_rbc_message + dt
    if self.state.last_rbc_message > 2 then  -- Every 2 seconds
        self:send_position_report(position, current_speed)
        self.state.last_rbc_message = 0
    end
    
    -- Build SSD (Speed Supervision Data)
    self:build_ssd()
    
    -- Mode management
    if self.state.current_mode == "SB" then
        self.state.current_mode = "FS"  -- Transition to Full Supervision
    end
end

function etcs:request_rbc_authorization()
    print(string.format("[ETCS-L2] Solicitando autorización a RBC (%s)", self.state.rbc_id))
    print("[ETCS-L2] Modo: SB (Stand By) -> FS (Full Supervision)")
end

function etcs:send_position_report(position, speed)
    local report = {
        timestamp = os.time(),
        position = position,
        speed = speed,
        level = 2,
        mode = self.state.current_mode
    }
    
    -- Simulated GSM-R transmission
    if math.random(1, 100) > 5 then  -- 95% reliable link
        print(string.format("[ETCS-L2] Reporte enviado: Pos=%.1fm, V=%d km/h", position, speed))
    else
        print("[ETCS-L2] ⚠️  Pérdida de enlace GSM-R")
        self.state.gsm_r_connected = false
    end
end

function etcs:on_gsm_r_loss()
    print("[ETCS-L2] 🚨 Pérdida de conexión GSM-R")
    print("[ETCS-L2] Transición a Level 1 (Eurobalise)")
    
    self.state.current_level = etcs.LEVELS.LEVEL_1
    self:add_dmi_message("GSM-R perdido. Modo Level 1", "warning")
    
    -- Begin emergency deceleration
    if self.train then
        self.train:apply_service_brake(0.5)  -- 50% service brake
    end
end

function etcs:build_ssd()
    -- Speed Supervision Data: contains speed profile for train movement
    -- Built from RBC data (gradient, curves, speed restrictions)
    
    self.state.ssd_active = true
    
    -- Simulated SSD points
    self.state.ssd_curve = {
        {distance = 0, speed = self.state.ceiling_speed},
        {distance = 500, speed = self.state.ceiling_speed},
        {distance = 1000, speed = 100},
        {distance = 1500, speed = 60},
        {distance = 2000, speed = 0}  -- Stop point
    }
end

-- ============= LEVEL 3 Implementation (CBTC) =============

function etcs:update_level_3(dt, current_speed, position)
    -- Level 3: Communication-Based Train Control
    -- No line-side signals needed, continuous communication with ATO (Automatic Train Operation)
    
    print("[ETCS-L3] Operación CBTC con autorización continua")
    
    -- Request movement authority from ATO system
    self:request_ato_authority(position, current_speed)
end

function etcs:request_ato_authority(position, speed)
    -- Simulated ATO (Automatic Train Operation) request
    print(string.format("[ETCS-L3] Solicitando autorización de movimiento: Pos=%.1fm", position))
end

-- ============= SSD (Speed Supervision Data) Management =============

function etcs:update_ssd(dt)
    if not self.state.ssd_curve or #self.state.ssd_curve == 0 then
        return
    end
    
    -- Find current point in SSD
    local current_allowed_speed = self.state.ceiling_speed
    
    for i, point in ipairs(self.state.ssd_curve) do
        -- Simple interpolation for current position
        if i < #self.state.ssd_curve then
            local next_point = self.state.ssd_curve[i + 1]
            if self.state.permission_distance <= next_point.distance then
                current_allowed_speed = point.speed
                break
            end
        end
    end
    
    self.state.allowed_speed = current_allowed_speed
end

-- ============= Speed Supervision =============

function etcs:supervise_speed()
    local speed_ratio = self.state.current_speed / self.state.ceiling_speed
    
    if speed_ratio >= self.config.intervention_threshold then
        -- Speed intervention required
        self:trigger_speed_intervention()
    elseif speed_ratio >= self.config.warning_threshold then
        -- Speed warning
        self:trigger_speed_warning()
    end
end

function etcs:trigger_speed_warning()
    self:add_dmi_message("⚠️  VELOCIDAD ELEVADA", "warning")
    print(string.format("[ETCS] Aviso de velocidad: %.1f%% de límite", 
        (self.state.current_speed / self.state.ceiling_speed) * 100))
end

function etcs:trigger_speed_intervention()
    print(string.format("[ETCS] 🚨 INTERVENCIÓN: Velocidad %.1f km/h > Límite %.1f km/h",
        self.state.current_speed, self.state.ceiling_speed))
    
    self:add_dmi_message("🚨 VELOCIDAD EXCEDIDA - FRENADO", "emergency")
    
    if self.train then
        self.train:apply_service_brake(0.8)  -- 80% service brake
    end
end

-- ============= DMI (Driver Machine Interface) =============

function etcs:update_dmi()
    -- Update visual display with current ETCS information
    -- Simulated on-board display
end

function etcs:add_dmi_message(message, level)
    -- level: "info", "warning", "emergency"
    table.insert(self.state.dmi_messages, {
        text = message,
        level = level,
        timestamp = os.time()
    })
    
    -- Keep only last 10 messages
    if #self.state.dmi_messages > 10 then
        table.remove(self.state.dmi_messages, 1)
    end
    
    print(string.format("[DMI] %s", message))
end

function etcs:display_dmi()
    print("\n=== DMI DISPLAY ===")
    print(string.format("Level: %s | Mode: %s", 
        etcs.LEVEL_NAMES[self.state.current_level], self.state.current_mode))
    print(string.format("Ceiling Speed: %d km/h | Current: %d km/h | Allowed: %d km/h",
        self.state.ceiling_speed, self.state.current_speed, self.state.allowed_speed))
    print(string.format("Permission Distance: %.1f m", self.state.permission_distance))
    print("--- Messages ---")
    for _, msg in ipairs(self.state.dmi_messages) do
        print(string.format("[%s] %s", msg.level, msg.text))
    end
    print("==================\n")
end

-- ============= Mode Transitions =============

function etcs:transition_mode(target_mode)
    if self.state.mode_transition_in_progress then
        return false
    end
    
    print(string.format("[ETCS] Transición de modo: %s -> %s", 
        self.state.current_mode, target_mode))
    
    self.state.mode_transition_in_progress = true
    self.state.mode_transition_target = target_mode
    
    return true
end

function etcs:complete_mode_transition()
    self.state.current_mode = self.state.mode_transition_target
    self.state.mode_transition_in_progress = false
    print(string.format("[ETCS] Transición completada. Modo actual: %s", self.state.current_mode))
end

-- ============= Level Transitions =============

function etcs:transition_level(target_level)
    if not self.config.equipped_levels[target_level] then
        print(string.format("[ETCS] Error: Nivel %d no equipado", target_level))
        return false
    end
    
    print(string.format("[ETCS] Transición de nivel: %s -> %s",
        etcs.LEVEL_NAMES[self.state.current_level],
        etcs.LEVEL_NAMES[target_level]))
    
    -- Graceful shutdown of current level
    if self.state.current_level == etcs.LEVELS.LEVEL_2 then
        -- Notify RBC before disconnecting
    elseif self.state.current_level == etcs.LEVELS.STM_LZB then
        -- Release LZB resources
    end
    
    self.state.current_level = target_level
    self.state.current_mode = "SB"  -- Reset to Stand By
    
    -- Initialize new level
    if target_level == etcs.LEVELS.STM_LZB then
        self:init_lzb_connection()
    elseif target_level == etcs.LEVELS.LEVEL_2 then
        self:init_gsm_r_connection()
    end
    
    return true
end

-- ============= Status and Diagnostics =============

function etcs:get_status()
    return {
        level = self.state.current_level,
        level_name = etcs.LEVEL_NAMES[self.state.current_level],
        mode = self.state.current_mode,
        ceiling_speed = self.state.ceiling_speed,
        allowed_speed = self.state.allowed_speed,
        current_speed = self.state.current_speed,
        target_speed = self.state.target_speed,
        permission_distance = self.state.permission_distance,
        ssd_active = self.state.ssd_active,
        emergency_stop = self.state.emergency_stop_active,
        last_balise = self.state.last_balise_id,
        gsm_r_connected = self.state.gsm_r_connected,
        rbc_id = self.state.rbc_id
    }
end

function etcs:get_track_speed_limit()
    -- Simulate track speed limit based on position
    return 160  -- Default
end

function etcs:reset()
    self.state.current_level = etcs.LEVELS.LEVEL_2
    self.state.current_mode = "SB"
    self.state.current_speed = 0
    self.state.emergency_stop_active = false
    print("[ETCS] Sistema reiniciado")
    return true
end

return etcs

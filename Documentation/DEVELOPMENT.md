# Guía de Desarrollo - RENFE Serie 256 ASFA-ETCS

## Estructura de Desarrollo

### Dependencias

```lua
-- Scripts principales
local asfa = require("Scripts/ASFA/asfa_digital")
local etcs = require("Scripts/ETCS/etcs_multilevel")
local bridge = require("Scripts/Integration/asfa_etcs_bridge")
local controller = require("Scripts/Integration/main_controller")
```

### Flujo de Ejecución

```
1. main_controller:init()        → Inicializar todos los sistemas
2. main_controller:update(dt)    → Actualizar en cada frame
3. Sistemas internos procesan    → ASFA, ETCS actualizan estado
4. Bridge sincroniza             → Validar consistencia
5. Aplicaciones externas reciben → Via puerto 9001
```

## Extensiones Personalizadas

### Agregar un nuevo modo ETCS

```lua
-- En Scripts/ETCS/etcs_multilevel.lua

etcs.MODES.CUSTOM = "CUSTOM"

function etcs:update_custom_mode(dt, current_speed)
    -- Tu lógica aquí
    print("[ETCS-CUSTOM] Ejecutando modo personalizado")
end

-- Llamar desde update()
if self.state.current_level == etcs.LEVELS.YOUR_LEVEL then
    self:update_custom_mode(dt, current_speed)
end
```

### Agregar nuevos tipos de mensajes ASFA

```lua
-- En Scripts/ASFA/asfa_digital.lua

asfa.CUSTOM_EVENTS = {
    JUNCTION_AHEAD = "JUNCTION",
    CURVE_WARNING = "CURVE"
}

function asfa:on_junction_detected()
    print("[ASFA] Cruce detectado")
    self:trigger_yellow_warning()  -- Usar sistema existente
end
```

### Agregar manejadores personalizados al bridge

```lua
-- En Scripts/Integration/asfa_etcs_bridge.lua

function asfa_etcs_bridge:handle_custom_message(message)
    print(string.format("[Bridge-Custom] %s", message.type))
    -- Tu lógica aquí
end

-- Registrar en process_internal_message()
function asfa_etcs_bridge:process_internal_message(message)
    -- ... mensajes existentes ...
    elseif message.type == "CUSTOM_TYPE" then
        self:handle_custom_message(message)
    end
end
```

## Testing

### Unit Tests

```lua
-- test_asfa.lua
local asfa = require("Scripts/ASFA/asfa_digital")

function test_asfa_signal_detection()
    asfa:init(mock_train)
    
    -- Test yellow signal
    asfa:detect_signal(1688)
    assert(asfa.state.current_signal == "YELLOW", "Yellow signal not detected")
    assert(asfa.state.speed_limit == 60, "Yellow speed limit incorrect")
    
    print("✓ ASFA signal detection test passed")
end

function test_asfa_alarm_trigger()
    asfa:init(mock_train)
    asfa:trigger_red_alarm()
    
    assert(asfa.state.alarm_active == true, "Alarm not activated")
    assert(asfa.state.ack_required == true, "ACK not required")
    
    print("✓ ASFA alarm trigger test passed")
end

test_asfa_signal_detection()
test_asfa_alarm_trigger()
```

### Integration Tests

```lua
-- test_integration.lua
local asfa = require("Scripts/ASFA/asfa_digital")
local etcs = require("Scripts/ETCS/etcs_multilevel")
local bridge = require("Scripts/Integration/asfa_etcs_bridge")

function test_speed_conflict_resolution()
    bridge:init(asfa, etcs, "INTERNAL")
    
    -- ASFA limita a 60 km/h
    asfa:detect_signal(1688)
    
    -- ETCS limita a 100 km/h
    etcs.state.ceiling_speed = 100
    
    -- Bridge debe resolver al más conservador (60)
    bridge:validate_speed_consistency(100)
    
    print("✓ Speed conflict resolution test passed")
end

test_speed_conflict_resolution()
```

## Performance

### Profiling

```lua
-- Medir tiempo de ejecución
local start = os.clock()

for i = 1, 1000 do
    asfa:update(0.016, 80, 1688)
    etcs:update(0.016, 80, 1000)
    bridge:update(0.016)
end

local elapsed = os.clock() - start
print(string.format("1000 updates en %.3f segundos (%.1f us/update)",
    elapsed, (elapsed * 1000000) / 1000))
```

### Optimizaciones

1. **Cache de frecuencias ASFA**
   ```lua
   -- Evitar búsquedas repetidas
   local FREQ_CACHE = {}
   function asfa:get_signal_type_cached(freq)
       if not FREQ_CACHE[freq] then
           FREQ_CACHE[freq] = self:get_signal_type(freq)
       end
       return FREQ_CACHE[freq]
   end
   ```

2. **Actualización selectiva del DMI**
   ```lua
   -- Solo actualizar si cambió
   if last_speed ~= current_speed then
       dmi:update_speed(current_speed)
       last_speed = current_speed
   end
   ```

## Debugging

### Logs detallados

```lua
-- Habilitar logs
local DEBUG = true

function log_debug(msg)
    if DEBUG then
        print("[DEBUG] " .. msg)
    end
end

-- Uso
log_debug(string.format("Speed: %d km/h, Limit: %d km/h",
    current_speed, speed_limit))
```

### Breakpoints y inspection

```lua
-- Pausar ejecución y mostrar estado
function inspect_system_state()
    print("\n=== ASFA STATE ===")
    for k, v in pairs(asfa.state) do
        print(string.format("%s = %s", k, tostring(v)))
    end
    
    print("\n=== ETCS STATE ===")
    for k, v in pairs(etcs.state) do
        print(string.format("%s = %s", k, tostring(v)))
    end
end
```

## Contribuciones

### Proceso de contribución

1. Fork el repositorio
2. Crear rama: `git checkout -b feature/tu-feature`
3. Implementar cambios
4. Escribir tests
5. Commit: `git commit -m 'Add tu-feature'`
6. Push: `git push origin feature/tu-feature`
7. Pull Request

### Estándares de código

- **Indentación**: 4 espacios
- **Comentarios**: Español/Inglés, claros
- **Nombres de funciones**: snake_case
- **Nombres de variables**: snake_case
- **Constantes**: UPPER_CASE
- **Documentación**: Incluir docstrings

### Ejemplo de función bien documentada

```lua
--- Detecta una señal ASFA en la línea
-- @param frequency número - Frecuencia de la señal en Hz
-- @return string - Tipo de señal detectada (YELLOW, RED, WHITE)
-- @usage
--   local signal_type = asfa:detect_signal(1688)
--   if signal_type == "YELLOW" then
--       print("Reducir velocidad")
--   end
function asfa:detect_signal(frequency)
    -- implementación
    return self.state.current_signal
end
```

## Versionado

Seguimos Semantic Versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Cambios incompatibles
- **MINOR**: Nuevas features compatibles
- **PATCH**: Bugfixes

Ejemplo: v1.2.3

## Roadmap

- [ ] Soporte Level 3 (CBTC completo)
- [ ] Integración con sistema de catenaria 3D
- [ ] Pantalla DMI touchscreen interactiva
- [ ] Grabación y reproducción de simulaciones
- [ ] Aplicación web de monitoreo
- [ ] Exportación de datos a CSV/JSON

---

**Para más información:** Ver README.md y INTEGRATION_GUIDE.md

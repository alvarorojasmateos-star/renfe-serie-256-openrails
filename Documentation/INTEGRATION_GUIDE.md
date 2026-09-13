# Guía de Integración ASFA-ETCS para Open Rails

## Índice
1. [Introducción](#introducción)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Instalación](#instalación)
4. [Configuración](#configuración)
5. [Integración Interna](#integración-interna)
6. [Integración Externa](#integración-externa)
7. [Ejemplos de Uso](#ejemplos-de-uso)
8. [Solución de Problemas](#solución-de-problemas)

---

## Introducción

Este documento describe cómo integrar y utilizar los sistemas ASFA Digital y ETCS Multi-Nivel en Open Rails con el tren RENFE Serie 256.

### Características Principales

- **ASFA Digital**: Sistema de seguridad automático con detección de señales
- **ETCS Multi-Nivel**: Soporte para STM LZB, Level 0, Level 1, Level 2 y Level 3
- **Puente de Integración**: Comunicación interna entre ASFA y ETCS
- **Conexión Externa**: API para aplicaciones externas
- **Resolución de Conflictos**: Gestión automática de inconsistencias

---

## Arquitectura del Sistema

### Componentes Principales

```
┌─────────────────────────────────────────────────────┐
│         SISTEMA DE SEGURIDAD FERROVIARIO             │
│                  SERIE 256 RENFE                      │
└─────────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
    ┌───▼───┐      ┌───▼───┐      ┌───▼───────┐
    │ ASFA  │      │ ETCS  │      │   BRIDGE  │
    │Digit. │      │Multi-│      │ (Integr.) │
    └───┬───┘      │ Level │      └───┬───────┘
        │          └───┬───┘          │
        │              │              │
        └──────────────┼──────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
    ┌───▼──────┐             ┌───────▼─────┐
    │  CABINA  │             │ APLICACIONES │
    │  3D      │             │  EXTERNAS    │
    └──────────┘             └──────────────┘
```

### Flujo de Datos

1. **Detección de Señales**: ASFA detecta señales de línea (1688 Hz, 1998 Hz)
2. **Comunicación RBC**: ETCS establece enlace con centro de control (GSM-R)
3. **Sincronización**: Bridge valida límites de velocidad entre sistemas
4. **Ejecución de Mandos**: Envío de comandos a frenos y motores
5. **Retroalimentación**: DMI muestra estado a maquinista
6. **Conexión Externa**: Aplicaciones externas pueden monitorear/controlar

---

## Instalación

### Requisitos Previos

```bash
- Open Rails 1.8+
- Lua 5.1+ (incluido en Open Rails)
- Python 3.7+ (para aplicaciones externas opcionales)
```

### Pasos de Instalación

1. **Clonar el repositorio**
```bash
git clone https://github.com/alvarorojasmateos-star/renfe-serie-256-openrails.git
cd renfe-serie-256-openrails
```

2. **Copiar a carpeta de Open Rails**
```bash
cp -r . "C:\Program Files\Open Rails\Content\Trains\Consist\RENFE\"
```

3. **Verificar estructura de directorios**
```
renfe-serie-256-openrails/
├── Scripts/
│   ├── ASFA/
│   ├── ETCS/
│   └── Integration/
├── Config/
├── Models/
└── Documentation/
```

---

## Configuración

### Archivo Principal: asfa_etcs_config.xml

Ubicación: `Config/asfa_etcs_config.xml`

#### Configurar ASFA

```xml
<ASFASystem>
    <Enabled>true</Enabled>
    <Version>2.0</Version>
    <Frequencies>
        <YellowSignal hz="1688" />      <!-- Reducir velocidad -->
        <RedSignal hz="1998" />          <!-- Parada obligatoria -->
        <WhiteSignal hz="2000" />        <!-- Vía libre -->
    </Frequencies>
    <SpeedLimits>
        <Yellow kmh="60" />
        <Red kmh="0" />
        <White kmh="160" />
    </SpeedLimits>
</ASFASystem>
```

#### Configurar ETCS

```xml
<ETCSSystem>
    <DefaultLevel>Level2</DefaultLevel>
    <EquippedLevels>
        <Level name="STM_LZB" equipped="true" />
        <Level name="Level0" equipped="true" />
        <Level name="Level1" equipped="true" />
        <Level name="Level2" equipped="true" />
    </EquippedLevels>
</ETCSSystem>
```

#### Configurar Puente de Integración

```xml
<IntegrationBridge>
    <Mode>HYBRID</Mode>  <!-- INTERNAL, EXTERNAL, o HYBRID -->
    <InternalCommunication>
        <Enabled>true</Enabled>
        <SyncInterval seconds="0.5" />
        <ConflictResolution strategy="CONSERVATIVE" />
    </InternalCommunication>
    <ExternalCommunication>
        <Enabled>true</Enabled>
        <Port>9001</Port>
    </ExternalCommunication>
</IntegrationBridge>
```

---

## Integración Interna

### Carga de Módulos en Open Rails

**Archivo**: `Scripts/Integration/main_controller.lua`

```lua
-- Cargar sistemas
local asfa = require("ASFA/asfa_digital")
local etcs = require("ETCS/etcs_multilevel")
local bridge = require("Integration/asfa_etcs_bridge")

-- Inicializar
function initialize()
    asfa:init(train)
    etcs:init(train, 12)  -- Level 2
    bridge:init(asfa, etcs, "HYBRID")
    print("[MAIN] Sistemas inicializados")
end

-- Loop de actualización
function update(dt, current_speed, position)
    -- Actualizar ASFA
    asfa:update(dt, current_speed, detected_signal)
    
    -- Actualizar ETCS
    etcs:update(dt, current_speed, position)
    
    -- Sincronizar a través del puente
    bridge:update(dt)
    
    -- Obtener status combinado
    local status = bridge:get_status()
    return status
end
```

### Comunicación Interna: Ejemplo

```lua
-- Cuando ASFA detecta una señal roja
asfa:trigger_red_alarm()

-- El puente captura esto automáticamente
bridge:send_internal(
    asfa_etcs_bridge.MSG_TYPES.ASFA_ALARM,
    {
        alarm_type = "RED",
        frequency = 1998,
        speed_limit = 0
    },
    "ASFA"
)

-- ETCS recibe la alarma y ajusta parámetros
etcs:supervise_speed()
```

---

## Integración Externa

### Conexión via TCP/JSON

#### Servidor (Open Rails)

El puente ASFA-ETCS expone un servidor en puerto **9001** (configurable).

```lua
-- En asfa_etcs_bridge.lua
function asfa_etcs_bridge:init_external_connection()
    -- Escuchar en puerto 9001
    -- Aceptar conexiones JSON
end
```

#### Cliente Python (Ejemplo)

```python
import json
import socket
import time

class RenfeClient:
    def __init__(self, host='localhost', port=9001):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((host, port))
    
    def send_command(self, cmd_type, payload):
        """Enviar comando a Open Rails"""
        message = {
            'type': cmd_type,
            'payload': payload,
            'timestamp': int(time.time())
        }
        self.sock.sendall(json.dumps(message).encode() + b'\n')
    
    def receive_status(self):
        """Recibir status del tren"""
        data = self.sock.recv(4096)
        return json.loads(data.decode())
    
    def query_status(self):
        """Consultar estado actual"""
        self.send_command('QUERY_STATUS', {})
        return self.receive_status()
    
    def inject_signal(self, frequency):
        """Inyectar señal ASFA externa"""
        self.send_command('EXTERNAL_SIGNAL', {
            'signal_type': 'ASFA',
            'frequency': frequency
        })
    
    def set_parameter(self, param, value):
        """Cambiar parámetro del sistema"""
        self.send_command('SET_PARAMETER', {
            'parameter': param,
            'value': value
        })

# Uso
client = RenfeClient()
status = client.query_status()
print(f"Velocidad: {status['etcs_status']['current_speed']} km/h")
print(f"Límite: {status['etcs_status']['ceiling_speed']} km/h")

# Inyectar señal amarilla
client.inject_signal(1688)

# Cambiar parámetro
client.set_parameter('etcs_level', 11)  # Level 1
```

#### Cliente JavaScript (Ejemplo)

```javascript
class RenfeClient {
    constructor(host = 'localhost', port = 9001) {
        this.url = `ws://${host}:${port}`;
        this.ws = new WebSocket(this.url);
        this.ws.onopen = () => console.log('Conectado');
        this.ws.onmessage = (e) => this.handleMessage(JSON.parse(e.data));
    }
    
    sendCommand(type, payload) {
        this.ws.send(JSON.stringify({
            type: type,
            payload: payload,
            timestamp: Date.now()
        }));
    }
    
    queryStatus() {
        this.sendCommand('QUERY_STATUS', {});
    }
    
    injectSignal(frequency) {
        this.sendCommand('EXTERNAL_SIGNAL', {
            signal_type: 'ASFA',
            frequency: frequency
        });
    }
    
    handleMessage(msg) {
        console.log('Recibido:', msg.type);
        if (msg.type === 'STATUS_RESPONSE') {
            updateDashboard(msg.payload);
        }
    }
}

// Uso
const client = new RenfeClient();
setInterval(() => client.queryStatus(), 1000);
```

### Formato de Mensajes

#### Solicitud de Status

```json
{
    "type": "QUERY_STATUS",
    "timestamp": 1694609400,
    "payload": {}
}
```

#### Respuesta de Status

```json
{
    "type": "STATUS_RESPONSE",
    "timestamp": 1694609400,
    "payload": {
        "asfa_status": {
            "system_active": true,
            "current_signal": "YELLOW",
            "speed_limit": 60,
            "current_speed": 75,
            "alarm_active": true
        },
        "etcs_status": {
            "level": 12,
            "level_name": "Level 2",
            "mode": "FS",
            "ceiling_speed": 60,
            "current_speed": 75,
            "permission_distance": 1500
        }
    }
}
```

#### Inyección de Señal Externa

```json
{
    "type": "EXTERNAL_SIGNAL",
    "timestamp": 1694609400,
    "payload": {
        "signal_type": "ASFA",
        "frequency": 1688,
        "id": "SIG_001"
    }
}
```

#### Cambio de Parámetro

```json
{
    "type": "SET_PARAMETER",
    "timestamp": 1694609400,
    "payload": {
        "parameter": "etcs_level",
        "value": 11
    }
}
```

---

## Ejemplos de Uso

### Ejemplo 1: Simulación Básica

```lua
-- main.lua
local asfa = require("Scripts/ASFA/asfa_digital")
local etcs = require("Scripts/ETCS/etcs_multilevel")
local bridge = require("Scripts/Integration/asfa_etcs_bridge")

function OnTrainStart()
    asfa:init(train)
    etcs:init(train, 12)  -- Level 2
    bridge:init(asfa, etcs, "INTERNAL")
end

function OnUpdate(dt)
    local speed = train:get_speed()
    local pos = train:get_position()
    
    -- Simular detección de señal (cada 5 km)
    if math.floor(pos) % 5000 == 0 then
        asfa:detect_signal(1688)  -- Señal amarilla
    end
    
    -- Actualizar sistemas
    asfa:update(dt, speed, 1688)
    etcs:update(dt, speed, pos)
    bridge:update(dt)
    
    -- Mostrar status
    bridge:display_status()
end

function OnKeyPress(key)
    if key == "A" then
        -- Confirmación de alarma ASFA
        asfa:driver_acknowledge()
    elseif key == "E" then
        -- Mostrar DMI ETCS
        etcs:display_dmi()
    end
end
```

### Ejemplo 2: Monitoreo Externo

```lua
-- Habilitar conexión externa
bridge:state.integration_mode = "HYBRID"
bridge:init_external_connection()

-- Aplicación externa recibe updates cada segundo
function OnUpdate(dt)
    asfa:update(dt, speed, signal)
    etcs:update(dt, speed, position)
    bridge:update(dt)
    
    -- Enviar status a aplicaciones externas
    if bridge.state.external_connected then
        local status = {
            asfa_signal = asfa.state.current_signal,
            asfa_speed_limit = asfa.state.speed_limit,
            etcs_level = etcs.state.current_level,
            etcs_mode = etcs.state.current_mode,
            train_speed = speed,
            timestamp = os.time()
        }
        bridge:send_external(status)
    end
end
```

### Ejemplo 3: Transición de Niveles ETCS

```lua
function transition_to_level_1()
    print("Transitioning to Level 1...")
    etcs:transition_level(11)  -- LEVEL_1
    
    -- Esperar a que se estabilice
    bridge:update(0.5)
    
    print("Transition complete")
end

function transition_to_level_2()
    print("Transitioning to Level 2...")
    etcs:transition_level(12)  -- LEVEL_2
    
    -- Iniciar conexión GSM-R
    etcs:init_gsm_r_connection()
    
    bridge:update(0.5)
    print("Level 2 active, GSM-R connected")
end
```

---

## Solución de Problemas

### ASFA no detecta señales

1. **Verificar frecuencias configuradas**
   ```xml
   <Frequencies>
       <YellowSignal hz="1688" />  <!-- Debe ser 1688 -->
       <RedSignal hz="1998" />      <!-- Debe ser 1998 -->
   </Frequencies>
   ```

2. **Comprobar que ASFA está habilitado**
   ```lua
   if asfa.config.enabled then
       asfa:detect_signal(frequency)
   end
   ```

3. **Revisar logs**
   ```bash
   tail -f Logs/ASFA_ETCS/asfa.log
   ```

### ETCS no establece enlace GSM-R

1. **Verificar RBC configurado**
   ```xml
   <RBCSettings>
       <DefaultRBC id="RBC_MADRID_01">
           <Frequency>876.4 MHz</Frequency>
       </DefaultRBC>
   </RBCSettings>
   ```

2. **Comprobar conexión**
   ```lua
   if etcs.state.gsm_r_connected then
       print("GSM-R OK")
   else
       print("GSM-R LOST - Revirtiendo a Level 1")
   end
   ```

### Conflictos entre ASFA y ETCS

El puente intenta resolverlos automáticamente:

```lua
-- Estrategia CONSERVATIVE: aplica el límite más bajo
<ConflictResolution strategy="CONSERVATIVE" />

-- Ejemplo:
-- ASFA límite: 60 km/h
-- ETCS límite: 100 km/h
-- → Se aplica: 60 km/h
```

Para investigar conflictos:

```lua
bridge:display_status()
-- Muestra mensajes de conflicto y cómo se resolvieron
```

### Conexión externa no funciona

1. **Verificar puerto abierto**
   ```bash
   netstat -an | grep 9001
   ```

2. **Revisar firewall**
   ```bash
   firewall-cmd --add-port=9001/tcp
   ```

3. **Probar conexión manual**
   ```bash
   telnet localhost 9001
   ```

4. **Habilitar en config**
   ```xml
   <ExternalCommunication>
       <Enabled>true</Enabled>
       <Port>9001</Port>
   </ExternalCommunication>
   ```

---

## Contacto y Soporte

- **GitHub Issues**: [renfe-serie-256-openrails/issues](https://github.com/alvarorojasmateos-star/renfe-serie-256-openrails/issues)
- **Documentación**: `Documentation/` en el repositorio
- **Ejemplos**: `Scripts/Examples/` en el repositorio

---

**Versión**: 1.2.0  
**Última actualización**: 2026-09-13  
**Autor**: RENFE Serie 256 Open Rails Project

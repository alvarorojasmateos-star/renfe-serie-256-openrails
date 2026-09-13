# Especificaciones Técnicas - RENFE Serie 256

## 📐 Dimensiones y Pesos

### Estructura General
- **Longitud total**: 74.5 m
- **Ancho**: 2.65 m
- **Altura máxima**: 3.7 m
- **Distancia entre ejes**: 13.0 m
- **Voladizo delantero**: 2.1 m
- **Voladizo trasero**: 2.1 m

### Peso
- **Peso en vacío**: ~350 toneladas
- **Peso máximo en servicio**: ~420 toneladas
- **Carga máxima**: ~70 toneladas
- **Carga por eje**: 15 t/eje

### Distribución de Vagones
```
[MOTOR 1] ---- [REMOLQUE 1] ---- [REMOLQUE 2] ---- [MOTOR 2]
  23.5m           16.5m             16.5m            17.5m
```

## ⚡ Sistema Eléctrico

### Alimentación
- **Voltaje nominal**: 25 kV AC
- **Frecuencia**: 50 Hz
- **Tipo de catenaria**: Rígida con péndola
- **Intensidad nominal**: 600 A

### Pantógrafo
- **Tipo**: Carbón de dos brazos
- **Presión de contacto**: 7 kg (regulable)
- **Altura de elevación**: 0.8 - 1.5 m
- **Velocidad de subida**: 0.5 m/s

### Rectificación y Conversión
- **Transformador principal**: 1000 kVA
- **Convertidor**: IGBT trifásico
- **Tensión de tracción**: 650 V DC
- **Tensión auxiliar**: 380 V AC / 110 V DC

## 🚗 Motores y Transmisión

### Motores de Tracción
- **Tipo**: Motor asincrónico trifásico (ASMC)
- **Número de motores**: 4 (uno por bogie)
- **Potencia nominal**: 1.15 MW c/u
- **Potencia máxima**: 4.6 MW total
- **Velocidad nominal**: 900 rpm
- **Torque nominal**: 12,200 N·m

### Transmisión
- **Tipo**: Reductora de tornillo sin fin
- **Relación de reducción**: 6.4:1
- **Eficiencia**: 96%
- **Velocidad máxima rueda**: 1420 rpm

### Ruedas y Ejes
- **Diámetro de rueda**: 860 mm (nuevo)
- **Diámetro mínimo**: 770 mm
- **Número de ruedas**: 8
- **Material**: Acero para ruedas

## 🛑 Sistema de Frenado

### Freno Dinámico
- **Tipo**: Regenerativo + Reostático
- **Potencia de frenado**: 2.8 MW
- **Deceleración máxima**: -1.2 m/s²

### Freno de Servicio
- **Tipo**: Neumático Knorr-Bremse
- **Deceleración nominal**: -0.7 m/s²
- **Presión de aire**: 8 bar
- **Cilindros de freno**: 4 (uno por bogie)
- **Pastillas**: Orgánicas de cerámica

### Freno de Estacionamiento
- **Tipo**: De muelle en los motores
- **Resortes**: 4 muelle de acero
- **Capacidad de frenado**: Retiene en pendiente de 4%

### Sistema Anti-deslizamiento (ASR/ABS)
- **Función ASR**: Previene patinaje en tracción
- **Función ABS**: Previene bloqueo de ruedas
- **Rango de velocidad**: 0 - 160 km/h
- **Presión mínima de activación**: 3 bar

## 🚀 Prestaciones Dinámicas

### Velocidades
- **Velocidad máxima**: 160 km/h
- **Velocidad de circulación nominal**: 120 km/h
- **Velocidad mínima controlada**: 5 km/h
- **Velocidad en curvas (radio 250 m)**: 95 km/h

### Aceleraciones
- **Aceleración inicial (0-30 km/h)**: 1.3 m/s²
- **Aceleración media (0-100 km/h)**: 0.9 m/s²
- **Aceleración media (100-160 km/h)**: 0.4 m/s²

### Deceleraciones
- **Deceleración de servicio**: -0.7 m/s²
- **Deceleración de emergencia**: -1.2 m/s²
- **Deceleración en curva (R=250m)**: -0.5 m/s²

### Distancias de Frenado (a 100 km/h)
- **Con freno de servicio**: 195 m
- **Con freno de emergencia**: 120 m
- **Tiempo total de respuesta**: 2.5 s

## 🪑 Capacidad y Confortabilidad

### Ocupación
- **Número de asientos**: 386
- **Asientos de primera clase**: 80
- **Asientos de segunda clase**: 306
- **Plazas de pie máximas**: 482 total
- **Densidad máxima**: 5-6 pax/m²

### Espacios
- **Superficie útil**: 265 m²
- **Altura interior**: 2.10 m
- **Ancho de pasillos**: 1.2 m
- **Puertas**: 12 (3 por lateral, 4 motores)

### Confort
- **Suspensión primaria**: Muelles y amortiguadores
- **Suspensión secundaria**: Neumática
- **Aislamiento acústico**: 84 dB a 100 km/h (interior)
- **Aislamiento térmico**: Climatización ±2°C
- **Iluminación**: LED con regulación

## 🛠️ Bogíes

### Bogie Motor
- **Tipo**: Bi-motor, portante
- **Distancia entre ejes**: 2.5 m
- **Distancia entre bogíes**: 13.0 m
- **Carga nominal por eje**: 12.5 t

### Componentes
- **Suspensión primaria**: Muelles helicoidales (2 por eje)
- **Suspensión secundaria**: Fuelles neumáticos (4 por bogie)
- **Amortiguadores**: Doble efecto

### Rodadura
- **Tipo de rodillo**: Rodamientos de bolas
- **Husillos**: Rígidos con chavetas
- **Espesor de llanta**: 30 mm (nuevo) / 24 mm (límite desgaste)

## 🌡️ Sistemas Auxiliares

### Compresor de Aire
- **Tipo**: Compresor de tornillo
- **Caudal**: 100 l/min
- **Presión nominal**: 8 bar
- **Depósito principal**: 50 litros

### Sistema de Climatización
- **Tipo**: Aire acondicionado de techo
- **Potencia frigorífica**: 60 kW
- **Potencia calorífica**: 40 kW
- **Temperatura de consigna**: 20°C ±2°C

### Iluminación
- **Tipo**: LED SMD
- **Potencia total**: 15 kW
- **Nivel de iluminación**: 500 lux (interior) / 1000 lux (cabina)
- **Autonomía de emergencia**: 2 horas

### Sistema de Ventilación
- **Tipo**: Ventilación mecánica forzada
- **Caudal total**: 12,000 m³/h
- **Renovación de aire**: Cada 3 minutos

## 📡 Sistemas de Comunicación

### Radio Móvil Ferroviaria
- **Tipo**: GSM-R
- **Frecuencia**: 876-880 MHz
- **Rango de cobertura**: 25 km en línea recta
- **Tipos de llamada**: Voz, grupo, emisión

### Interfonía Interna
- **Puntos de comunicación**: 8
- **Tipo**: Digital
- **Interfaz**: Pulsador + micrófono

## 🔒 Seguridad Estructural

### Resistencia a Impacto
- **Tipo de choque frontal**: 1.0 MJ
- **Tipo de choque lateral**: 0.5 MJ
- **Deformación máxima permitida**: 50 mm

### Protección Contra Descarrilamiento
- **Pestaña de la llanta**: 30 mm de altura
- **Radio de curvatura mínimo**: Hasta 150 m
- **Velocidad máxima en curva (R=200m)**: 90 km/h

### Salidas de Emergencia
- **Número de puertas**: 12
- **Ventanillas de emergencia**: 12
- **Claraboyas**: 4 (para evacuación)
- **Tiempo máximo de evacuación**: 4 minutos

## 📊 Datos de Rendimiento

### Consumo Energético (por km)
- **Consumo específico**: 25 kWh/100 km
- **Consumo en aceleración**: 35 kWh/100 km
- **Consumo en regimen constante**: 18 kWh/100 km

### Tiempo de Respuesta
- **Tiempo de reacción (aceleración)**: < 0.5 s
- **Tiempo de reacción (frenado)**: < 2.5 s
- **Tiempo de cambio de equipo de tracción**: 1 s

### Disponibilidad y Mantenimiento
- **Disponibilidad objetivo**: > 95%
- **Intervalo de mantenimiento preventivo**: 100,000 km
- **Vida útil esperada**: 35 años

---

**Nota**: Estas especificaciones son aproximadas y basadas en datos técnicos de la RENFE Serie 250 (variante similar).

# Changelog - RENFE Serie 256 ASFA-ETCS

## [1.0.0] - 2026-09-13

### Added
- Sistema ASFA Digital completo
  - Detección de señales (Amarilla, Roja, Blanca)
  - Avisos acústicos y visuales
  - Vigilancia de conductor
  - Integración con frenos de emergencia

- Sistema ETCS Multi-Nivel
  - Soporte STM LZB (German legacy system)
  - Soporte ETCS Level 0 (Odometer-based)
  - Soporte ETCS Level 1 (Eurobalise-equipped)
  - Soporte ETCS Level 2 (GSM-R based) - PRIMARY
  - Preparación para Level 3 (CBTC)
  - DMI (Driver Machine Interface) integrada
  - SSD (Speed Supervision Data)
  - Modos de operación (SB, OS, LS, PS, FS, SH, UN)

- Puente de Integración ASFA-ETCS
  - Comunicación interna entre sistemas
  - Comunicación externa (TCP/JSON)
  - Resolución automática de conflictos
  - Sincronización de parámetros
  - Queue de mensajes internos

- Configuración XML completa
  - Parámetros de ASFA customizables
  - Parámetros de ETCS customizables
  - Configuración de integración
  - Parámetros del tren Serie 256

- Documentación completa
  - Especificaciones técnicas detalladas
  - Guía de integración
  - Guía de desarrollo
  - Ejemplos de uso

### Technical Details
- Implemented in Lua 5.1 (Open Rails compatible)
- JSON protocol for external communication
- Queue-based message passing
- Conservative conflict resolution strategy
- SIL3 safety integrity level architecture

## Future Releases

### [1.1.0] - Planned
- ETCS Level 3 full support
- Advanced DMI graphics
- Logging system improvements
- Performance optimizations

### [1.2.0] - Planned  
- Web-based monitoring dashboard
- CSV/JSON data export
- Simulation replay system
- Enhanced diagnostics

---

**Current Version**: 1.0.0  
**Release Date**: September 13, 2026  
**Status**: Stable

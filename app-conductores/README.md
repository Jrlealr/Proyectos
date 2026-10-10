# App Conductores Chile — Especificación v1

Guantera digital + Ley de Tránsito contextual para conductores particulares (autos y motos).

**Decisiones tomadas**
- Gratis para particulares.
- Android primero, en Flutter (para luego publicar en iOS con el mismo código).
- Datos 100% locales en el dispositivo (cifrados).
- Público: conductor particular.
- Monetización: "puntos de oferta" incluidos en v1, **desactivados** por defecto.

Ver [`docs/puntos-de-oferta.md`](docs/puntos-de-oferta.md) y [`assets/config/ofertas.json`](assets/config/ofertas.json).

## Desarrollo

```bash
flutter pub get
flutter test
flutter run        # con un emulador o dispositivo Android conectado
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `lib/guantera/` | Guantera digital: modelos, cifrado AES-256-GCM (clave en Keystore/Keychain), almacenamiento local, alertas de vencimiento |
| `lib/ofertas/` | Puntos de oferta (desactivados en v1) |
| `lib/ui/` | Pantallas: vehículos, documentos personales, vencimientos, ajustes |

## Guantera digital (v1)

- Vehículos (auto/moto) con patente validada.
- Documentos del vehículo (permiso, SOAP, revisión técnica, padrón, seguro, foto patente) y personales (licencia, cédula).
- Carga desde PDF, imagen, cámara o galería. Se guardan **cifrados** en el teléfono; se descifran solo en memoria para verlos.
- Fecha de vencimiento con estado (vigente / por vencer ≤30 días / vencido). Permiso y SOAP sugieren el 31 de marzo.
- Alertas locales 30, 15, 1 y 0 días antes, a las 9:00.
- Sin respaldo en la nube (la clave no viaja con los datos). Desinstalar la app borra los documentos.

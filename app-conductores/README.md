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
| `lib/ley/` | Ley de Tránsito: modelo, búsqueda sin tildes, temas |
| `tool/ley/` | `convertir.py` (XML oficial de LeyChile → JSON de la app) y el XML descargado |
| `lib/ofertas/` | Puntos de oferta (desactivados en v1) |
| `lib/ui/` | Pantallas: vehículos, documentos personales, vencimientos, ajustes |

## Guantera digital (v1)

- Vehículos (auto/moto) con patente validada.
- Documentos del vehículo (permiso, SOAP, revisión técnica, padrón, seguro, foto patente) y personales (licencia, cédula).
- Carga desde PDF, imagen, cámara o galería. Se guardan **cifrados** en el teléfono; se descifran solo en memoria para verlos.
- Fecha de vencimiento con estado (vigente / por vencer ≤30 días / vencido). Permiso y SOAP sugieren el 31 de marzo.
- Alertas locales 30, 15, 1 y 0 días antes, a las 9:00.
- **Modo fiscalización**: botón rojo en la pantalla de inicio. Elige el vehículo, muestra un resumen de los 5 documentos obligatorios (vigente / por vencer / vencido / no guardado) y luego cada documento en pantalla completa, brillo al máximo, pantalla siempre encendida y fondo blanco para leer el QR. Termina con una guía de qué hacer si no aceptan los documentos digitales. Sin ofertas.
- **Registro de controles** (pestaña Controles, o "Registrar" desde el Modo fiscalización): fecha y hora, vehículo, lugar con GPS opcional, institución, grado, nombre e identificación del funcionario, motivo, resultado; si hay citación: N° de boleta, infracción, Juzgado y fecha de comparecencia (aviso el día anterior y 2 horas antes). Fotos/PDF adjuntos cifrados. Botón para copiar un resumen en texto para los descargos. Sin grabación de audio (pendiente de revisión legal).
- Sin respaldo en la nube (la clave no viaja con los datos). Desinstalar la app borra los documentos.

## Ley de Tránsito

- Texto oficial vigente de la **Ley 18.290** (texto refundido DFL 1 de 2009, `idNorma=1007469`) desde **LeyChile (BCN)**, empaquetado en la app: funciona sin internet.
- Pestaña **Ley**: buscador (por palabras sin tildes o por número, ej. "art 96 bis"), 8 temas (documentos, fiscalización, infracciones, velocidad, alcohol, celular, motos, licencias) y ley completa. Si el usuario tiene moto, "Motocicletas" aparece arriba.
- Los temas se asignan **automáticamente por palabras clave**: son una ayuda para navegar, no una clasificación jurídica.
- **Actualización**: el workflow `.github/workflows/ley-transito.yml` descarga el XML cada lunes, regenera `assets/ley/ley_18290.json` y lo sube si cambió. La próxima compilación del APK incluye el texto nuevo.
- **Tabla de multas** (pestaña Ley → Tabla de multas): las 79 infracciones enumeradas en los arts. 199 (gravísimas), 200 (graves) y 201 (menos graves), extraídas del texto oficial; escala en UTM del art. 204 y su equivalente en pesos; reglas de reincidencia, concurso de infracciones y rebaja judicial citadas textualmente; enlaces a los arts. 204 y 207 (suspensión de licencia). Desde el registro de un control se puede elegir la infracción imputada desde la tabla.
- **UTM**: el mismo workflow guarda el valor mensual (`assets/ley/utm.json`, desde mindicador.cl) y una copia de la página del SII para contrastarlo.
- **Importante**: la Ley 18.290 exige *portar* licencia, permiso de circulación, SOAP y revisión técnica (arts. 5, 6, 51, 89), pero **no regula el formato digital**. Su aceptación depende de otras normas o instrucciones, que un abogado debe identificar antes de citarlas en la app.

# Puntos de oferta (monetización) — v1: listos y desactivados

Un *punto de oferta* es un botón de acción opcional que aparece **dentro de una alerta o pantalla que ya existe**
(ej. "Tu SOAP vence en 15 días"). En v1 el código y la UI quedan implementados, pero todos los flags están en `false`.

## Reglas obligatorias

1. **Flag global** `ofertas.habilitadas` + flag por oferta. Ambos deben estar en `true` para mostrar algo.
2. **Cálculo local**: la decisión de mostrar una oferta se toma en el dispositivo con los datos locales. No se envía nada a ningún servidor para decidirlo.
3. **Datos solo al tocar**: recién cuando el usuario toca el botón se comparte el mínimo indicado en `datosCompartidos`, previa pantalla de consentimiento explícito (una vez por oferta, revocable en Ajustes).
4. **Nunca en Modo Fiscalización**, ni en la pantalla de la Ley de Tránsito.
5. **Etiqueta visible** "Patrocinado" en todo botón de oferta.
6. **Frecuencia**: máximo 1 oferta por alerta; si el usuario la descarta, no reaparece en ese ciclo de vencimiento.
7. **Ajustes → "Ofertas y beneficios"**: interruptor para que el usuario las apague todas.
8. **Actualización de flags**: los flags vienen empaquetados en la app (`assets/config/ofertas.json`). Opcionalmente se puede descargar una versión nueva desde un JSON estático (GET sin identificadores del usuario). Así se activan sin publicar una versión nueva.

## Catálogo v1

| id | Dónde aparece | Disparador (local) | Botón | Datos compartidos al tocar |
|---|---|---|---|---|
| `soap_compra` | Alerta de vencimiento SOAP | SOAP vence en ≤ 30 días o vencido | "Comprar SOAP" | patente, tipo de vehículo |
| `seguro_cotizacion` | Ficha del vehículo | Vehículo sin seguro voluntario registrado | "Cotizar seguro" | patente, marca, modelo, año |
| `abogado_parte` | Registro de un parte / control | Usuario registra un parte | "Que un abogado lo revise" | comuna del Juzgado, tipo de infracción |
| `revision_tecnica_agenda` | Alerta de revisión técnica | RT vence en ≤ 30 días (según dígito de patente) | "Agendar revisión técnica" | comuna, tipo de vehículo |
| `taller_mantencion` | Ficha del vehículo | Recordatorio de mantención del usuario | "Talleres cercanos" | comuna |

## Pendientes antes de activar

- `soap_compra` / `seguro_cotizacion`: firmar un convenio de afiliado y confirmar con un abogado que el modelo no requiere inscripción como corredor en la CMF.
- `abogado_parte`: definir el modelo de cobro (suscripción o por contacto).
- Todos: texto de consentimiento revisado según la Ley 21.719 (vigente desde dic-2026).

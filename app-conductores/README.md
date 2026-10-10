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

Código de ofertas: `lib/ofertas/` (modelo + motor de elegibilidad, 100% local).

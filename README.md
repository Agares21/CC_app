# Cloud Contact Center Flutter

Cliente móvil y multiplataforma para el backend Laravel `cloud-api-cc`.

## Ejecutar

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/mobile
```

- Android Emulator: `10.0.2.2`
- iOS Simulator/Web/Desktop: normalmente `127.0.0.1`
- Dispositivo físico: usa la IP LAN del equipo que ejecuta Laravel.

## Arquitectura

- `core`: red, configuración, almacenamiento y tema.
- `features/*/domain`: entidades.
- `features/*/data`: repositorios y acceso API.
- `features/*/presentation`: pantallas y estado.
- `shared`: shell y navegación por rol.

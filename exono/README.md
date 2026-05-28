# Exono - Exhibition CRM Mobile App

Flutter mobile application for exhibition lead capture and relationship management.

## Features

- 📸 Business card scanning with OCR
- 📱 QR code scanning
- 🎤 Voice notes
- 👥 Contact management
- 📅 Event tracking
- 🤖 AI-powered enrichment
- 🌙 Dark mode support

## Prerequisites

- Flutter SDK 3.10.8 or higher
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Backend API running (see `/backend`)

## Setup

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure API Endpoint

Edit `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://YOUR_IP:3001/api';
```

**Important**: 
- Android Emulator: Use `http://10.0.2.2:3001/api`
- iOS Simulator: Use `http://localhost:3001/api`
- Physical Device: Use `http://YOUR_LOCAL_IP:3001/api`

### 3. Add Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan business cards</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice notes</string>
```

## Running the App

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run in release mode
flutter run --release
```

## Project Structure

```
lib/
├── config/
│   └── api_config.dart          # API configuration
├── models/
│   ├── contact.dart             # Contact data model
│   └── event.dart               # Event data model
├── services/
│   └── api_service.dart         # HTTP API client
├── screens/
│   ├── home_screen.dart         # Main navigation
│   ├── events_screen.dart       # Events list
│   ├── contacts_screen.dart     # Contacts list
│   └── capture_screen.dart      # Capture interface
└── main.dart                    # App entry point
```

## Building for Production

### Android

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
# Build for iOS
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode to archive and upload.

## Development

### Hot Reload

While the app is running, press `r` to hot reload or `R` to hot restart.

### Debug Mode

```bash
flutter run --debug
```

### Run Tests

```bash
flutter test
```

## Troubleshooting

### Cannot connect to API
- Ensure backend is running on port 3001
- Check API URL in `api_config.dart`
- For Android emulator, use `10.0.2.2` instead of `localhost`

### Camera not working
- Check permissions in AndroidManifest.xml / Info.plist
- Request runtime permissions
- Test on physical device (emulator cameras are limited)

### Build errors
```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

## Next Steps

- [ ] Implement QR scanner
- [ ] Add voice recording
- [ ] Create detail screens
- [ ] Add offline storage
- [ ] Implement search
- [ ] Add filters and sorting
- [ ] State management (Provider/Riverpod)
- [ ] Unit and widget tests

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/guides)
- [Material Design 3](https://m3.material.io/)

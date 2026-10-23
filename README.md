# Emergency App

Emergency App is a Flutter application for requesting emergency assistance,
communicating with responders, sending background SOS messages, and receiving
short first-aid guidance from an AI assistant.

The application has two primary experiences:

- **User experience:** request Police, Ambulance, or Fire Brigade assistance,
  share location, contact emergency services, chat with responders, and use
  the First-Aid Assistant.
- **Responder experience:** sign in as a Police, Ambulance, or Fire Brigade
  responder, monitor incoming requests, update request status, and chat with
  users.

> **Medical safety:** The First-Aid Assistant provides immediate first-aid
> information only. It is not a doctor, diagnosis tool, or replacement for
> emergency services. In a life-threatening situation, call the local
> emergency number immediately.

## Contents

- [Technology](#technology)
- [Features](#features)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Configuration](#configuration)
- [Install and run](#install-and-run)
- [User flow](#user-flow)
- [Responder/admin flow](#responderadmin-flow)
- [First-Aid Assistant](#first-aid-assistant)
- [Background SOS](#background-sos)
- [Firestore data model](#firestore-data-model)
- [Permissions](#permissions)
- [Security](#security)
- [Testing and validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)

## Technology

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- OpenRouter Chat Completions API
- NVIDIA Nemotron model through OpenRouter
- `http` for REST API calls
- `speech_to_text` for voice input
- `flutter_tts` for spoken responses
- Android Kotlin platform channel for SMS and Accessibility Settings
- `geolocator` and `geocoding` for location context
- `permission_handler` for runtime permissions

## Features

### User dashboard

- Emergency service request cards for Police, Ambulance, and Fire Brigade.
- Location detection and reverse geocoding.
- City-based responder targeting when a matching active service exists.
- Request status tracking.
- Emergency contacts.
- User profile, history, and theme support.
- Floating First-Aid Assistant button on the Home tab.
- Quick access to Background SOS setup.

### Responder dashboard

- Separate Police, Ambulance, and Fire Brigade entry points.
- Live request stream from Firestore.
- Filtering by `serviceType` and SOS target.
- Request status updates.
- Request location/map actions.
- User chat navigation.
- Dark/light theme support.

### First-Aid Assistant

- Full-screen emergency chat interface.
- Typed questions such as:
  - `My hand is burned`
  - `Snake bite treatment`
  - `Chest pain`
  - `My finger is bleeding`
- Voice input through speech recognition.
- Text-to-speech output.
- OpenRouter/NVIDIA online responses.
- Offline keyword fallback when the network or provider is unavailable.
- Exactly three actionable bullet points per response.

### Background SOS

- Android Accessibility Service registration.
- Opens Android Accessibility Settings from the Home page.
- Detects volume-button events through the native service.
- Sends emergency SMS through Android `SmsManager`.
- Stores the SOS message template and user data for native use.

## Project structure

```text
lib/
├── Admin/
│   ├── admin_dashboard_ui.dart
│   ├── AdminChatPage.dart
│   └── AdminConversationRoom.dart
├── Ambulance/
│   └── ambulance_dashboard.dart
├── Fire/
│   └── fire_dashboard.dart
├── User/
│   ├── user_dashboard.dart
│   ├── FirstAidChatPage.dart
│   ├── ChatPage.dart
│   └── ConversationRoom.dart
├── auth/
│   ├── login.dart
│   ├── admin_login.dart
│   └── admin_register.dart
├── services/
│   ├── first_aid_ai_service.dart
│   ├── sos_sms_service.dart
│   └── emergency_config.dart
└── main.dart

assets/
└── emergency_protocols.json

android/app/src/main/
├── AndroidManifest.xml
└── kotlin/com/example/app/
    ├── MainActivity.kt
    └── EmergencyAccessibilityService.kt
```

## Requirements

Install the following before starting:

- Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`.
- Android Studio and Android SDK for Android builds.
- A configured Firebase project.
- A physical Android device or emulator for testing.
- An OpenRouter API key for online First-Aid Assistant responses.

Background SOS and SMS should be tested on a physical Android phone. Android
emulators generally cannot reproduce the complete volume-button,
Accessibility-Service, SIM, and SMS behavior.

## Configuration

### Firebase

1. Create or use a Firebase project.
2. Register the Android application with the application ID from
   `android/app/build.gradle.kts`.
3. Place the Firebase Android configuration file at:

   ```text
   android/app/google-services.json
   ```

4. Enable:
   - Firebase Authentication
   - Cloud Firestore
   - Firebase Storage if the selected app flows require it
5. Deploy Firestore rules appropriate for your environment.

### Environment variables

Create `lib/.env` locally. The file is included as a Flutter asset at runtime
but is ignored by Git because it contains credentials.

```dotenv
OPEN_ROUTER_API_KEY="your-openrouter-key"
OPEN_ROUTER_MODEL="nvidia/nemotron-3-ultra-550b-a55b:free"
```

The service reads:

- `OPEN_ROUTER_API_KEY` for the bearer token.
- `OPEN_ROUTER_MODEL` for the OpenRouter model name.

The app uses the NVIDIA Nemotron model configured in the environment file. If
the key is missing, the app uses the offline fallback protocol instead of
showing a fabricated online response.

> Do not commit API keys. Any key previously shared publicly should be revoked
> and replaced. A mobile application cannot keep a client-side API key fully
> secret; production deployments should proxy provider requests through a
> secured backend.

### Emergency numbers

Review `lib/services/emergency_config.dart` and replace the configured
emergency numbers with the correct numbers for the deployment country before
testing or releasing the app.

## Install and run

From the repository root:

```bash
flutter pub get
flutter run
```

To run on a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

To create a debug Android APK:

```bash
flutter build apk --debug
```

The output is written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

To create a release APK:

```bash
flutter build apk --release
```

Configure release signing before distributing a release build.

## User flow

1. The user signs in or creates a user account.
2. The Home tab loads the profile and current location.
3. The user selects an emergency service.
4. The app creates a document in `requests`.
5. The matching responder dashboard receives the request in real time.
6. The responder updates the request status.
7. The user sees status changes through the request subscription.
8. The user can chat with the responder through the chat flow.

The user dashboard reads and writes normal user documents under lowercase
`users/{uid}`. Firestore collection names are case-sensitive.

## Responder/admin flow

Responder registration and login use the `EmergencyServices` collection. The
app does not use a separate `admins` collection.

1. Choose Police, Ambulance, or Fire Brigade.
2. Register the responder account with Firebase Authentication.
3. Store responder metadata in `EmergencyServices/{uid}`.
4. Sign in using the responder login screen.
5. The app validates the authenticated UID and `serviceType`.
6. The corresponding responder dashboard opens.

Supported service values:

```text
Police
Ambulance
Fire Brigade
```

## First-Aid Assistant

The assistant is available from the red medical floating action button on the
Home tab.

### Online response

`FirstAidAiService` sends a request to:

```text
https://openrouter.ai/api/v1/chat/completions
```

The system prompt requires:

1. Exactly three bullet points.
2. The first point to address emergency services.
3. The second and third points to provide critical actions or warnings.
4. No summary, heading, introduction, diagnosis, or extra text.

If an online response contains a `Summary:` section unexpectedly, the client
removes that section before displaying and speaking the response.

### Offline response

When the API key is unavailable, the request times out, the network fails, or
the provider returns an invalid response, the app loads:

```text
assets/emergency_protocols.json
```

The file currently contains keyword protocols for:

- Burns
- Bleeding and cuts
- Snake bites
- Chest pain and breathing emergencies
- Generic emergencies

Each offline protocol contains keywords and exactly three response steps.

### Voice

- Tap the microphone button to start speech recognition.
- Speak the emergency description.
- Review the transcribed text.
- Tap Send.
- The response is displayed and read aloud through text-to-speech.

Voice input requires microphone and speech-recognition permissions.

## Background SOS

### Setup on Android

1. Install a newly built APK. Uninstall an older development APK first if the
   service does not appear in Settings.
2. Open the app Home tab.
3. Tap **Enable Background SOS**.
4. Confirm the explanation dialog.
5. Tap **Open Settings**.
6. Select **Emergency App Background SOS**.
7. Enable the Accessibility Service.
8. Return to the app.

Some Android 13+ devices require:

```text
Settings → Apps → Emergency App → ⋮ → Allow restricted settings
```

After allowing restricted settings, return to Accessibility Settings and
enable the service again.

### SMS permission

The Android manifest declares `android.permission.SEND_SMS`. The app also
requests the permission at runtime using `permission_handler`.

If SMS permission was denied permanently:

1. Open Android App Settings.
2. Open Permissions.
3. Enable SMS.
4. Restart the app.

SMS requires a physical device with a working SIM and mobile service. A
successful APK build does not guarantee that an emulator or device can send
SMS.

### Native components

- `MainActivity.kt` handles the Flutter method channel.
- `EmergencyAccessibilityService.kt` registers the Accessibility Service and
  receives volume-key events.
- `AndroidManifest.xml` declares `SEND_SMS` and the Accessibility Service.
- `sos_sms_service.dart` requests permissions, builds the message, and invokes
  native methods.

## Firestore data model

### `users/{uid}`

Normal user profile. Typical fields include:

```text
uid
email
name or full_name
phone
bloodGroup
homeAddress
emergencyContact1
emergencyContact2
applicationStatus
role
```

### `EmergencyServices/{uid}`

Responder profile. Typical fields:

```text
uid
email
serviceType       // Police, Ambulance, Fire Brigade
serviceId
stationName
phone
zone
status            // active or inactive
rating
totalRequests
userType          // emergency_service
createdAt
```

The user service list reads active records from this collection. The
responder login also validates this document by authenticated UID.

### `requests/{requestId}`

Typical fields:

```text
requestId
userId
userEmail
userFullName
serviceType
alert_target
status
targetCity
assignedServiceId
location.latitude
location.longitude
location.address
location.area
location.city
location.district
createdAt
updatedAt
```

### `Chats/{roomId}/messages`

Room IDs are deterministic and are created by sorting the two participant UIDs.
Typical message fields:

```text
text
sender
timestamp
type
read
receiverName
receiverType
```

Collection names are case-sensitive. Use `users`, `EmergencyServices`,
`requests`, and `Chats` exactly as written.

## Permissions

The app may request the following permissions depending on the platform and
feature:

- Internet access for Firebase and OpenRouter.
- Fine/coarse location for emergency request location.
- Background location for SOS context.
- SMS for emergency message delivery.
- Microphone for speech-to-text.
- Speech recognition for voice input.
- Accessibility Service permission for background SOS.

Users can deny any runtime permission. The app should show a clear recovery
path through Android App Settings or the relevant system settings screen.

## Security

- Never commit `lib/.env`, API keys, Firebase private credentials, keystores,
  or signing passwords.
- Rotate credentials that have been exposed.
- Use restrictive Firestore rules in production.
- Validate authenticated UIDs and responder roles on the server side, not only
  in Flutter code.
- Restrict who can read and update `requests`.
- Restrict chat messages to room participants.
- Restrict responder documents so users cannot impersonate or modify services.
- Consider moving OpenRouter calls to a backend before production release.
- Test SMS and Accessibility behavior only with explicit user consent.

## Testing and validation

Format the changed Dart files:

```bash
dart format lib
```

Run static analysis:

```bash
flutter analyze
```

Run the test suite:

```bash
flutter test
```

Run a debug build:

```bash
flutter build apk --debug
```

Check the working tree for whitespace errors:

```bash
git diff --check
```

## Troubleshooting

### The First-Aid Assistant shows offline responses

Check that:

- `lib/.env` exists.
- `OPEN_ROUTER_API_KEY` is present and valid.
- `OPEN_ROUTER_MODEL` is spelled correctly.
- `lib/.env` is listed in `pubspec.yaml` assets.
- The device has internet access.

The offline fallback is expected when the provider is unavailable.

### Emergency App does not appear in Accessibility Settings

- Rebuild and reinstall the APK.
- Uninstall the old APK before installing the new debug APK.
- Confirm the Accessibility Service declaration exists in the manifest.
- On Android 13+, enable **Allow restricted settings**.
- Open Accessibility Settings again.

### SMS permission is denied or no SMS option appears

- Install the APK after the `SEND_SMS` manifest permission was added.
- Check Android App Settings → Permissions → SMS.
- If the permission is permanently denied, enable it manually in App Settings.
- Use a physical Android phone with a SIM.
- Confirm the configured emergency number is valid.
- Do not rely on an emulator for SMS testing.

### Firebase data is not visible

- Confirm the Firebase project and `google-services.json` match.
- Check collection name capitalization.
- Check Firestore rules and authenticated user state.
- Verify that responder records are in `EmergencyServices`, not `admins`.
- Verify that user records are in lowercase `users`, not `Users`.

### Requests are not appearing for responders

- Confirm the request `serviceType` matches `Police`, `Ambulance`, or
  `Fire Brigade`.
- Confirm the responder record has `status: "active"`.
- Check the request `alert_target` and city targeting fields.
- Review Firestore rules and indexes in the Firebase console.

## License and responsibility

This project is intended for hackathon and development use. Add an
appropriate license before distributing it. Emergency and medical behavior
must be reviewed, tested, and approved for the target country and deployment
environment before production use.

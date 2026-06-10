# Resource Plus - Project Handover Documentation

## 1. Project Overview
Resource Plus is a modern, feature-rich Human Resources mobile application built with Flutter. It serves as a comprehensive employee portal allowing users to manage their work life effectively. The core functionalities include geo-fenced attendance marking (HR Portal) with selfie captures, viewing dashboard statistics, managing employee profiles, accessing company notifications, and utilizing a calendar system. The application employs a unique multi-tenant architecture, allowing different organizations (instances) to securely access their specific environments by scanning a unique QR code upon initial setup.

## 2. Technology Stack
- **Framework:** Flutter (SDK ^3.8.1)
- **Language:** Dart
- **State Management:** GetX (^4.6.6)
- **Architecture Pattern:** Feature-first Modular Architecture (GetX Pattern)
- **Networking / API:** Dio (^5.4.0) with custom SSL configuration
- **Local Storage:** GetStorage (^2.1.1) for secure, lightweight key-value persistence
- **Authentication:** Local Auth (^2.1.8) for Biometric login (Fingerprint/FaceID)
- **Location Services:** Geolocator (^13.0.1) for attendance tracking
- **Camera:** Camera (^0.11.0+2) for selfie-based attendance punching
- **QR Scanning:** Mobile Scanner (^3.5.0) for multi-tenant instance resolution
- **Notifications:** Flutter Local Notifications (^17.2.2) for push and local alerts
- **Date & Calendar:** Table Calendar (^3.0.9), Intl (^0.19.0)

## 3. Application Architecture
The application employs a strict **Feature-first Modular Architecture** heavily powered by GetX.
- **GetX Pattern:** The application logic is clearly separated into Bindings, Controllers, and Views. 
- **Service Layer:** Core device and network functionalities (e.g., `ApiService`, `NotificationService`, `PermissionService`) act as singletons or globally injected services.
- **Data Flow:** The UI (Views) reacts to state changes in Controllers via `.obs` (Observables) and `Obx` widgets. Controllers handle business logic, process user input, and communicate with the API layer via `Dio`. Responses update the reactive variables, which seamlessly triggers UI rebuilds.

## 4. Folder Structure Explanation
The codebase strictly separates concerns to ensure scalability:
```text
lib/
├── app/
│   ├── config/         # App-wide configurations (e.g., Google Auth Config)
│   ├── controllers/    # Global controllers managing Theme and Language (i18n)
│   ├── modules/        # Feature modules containing Views, Controllers, and Bindings
│   │   ├── auth/       # Instance Scan, Login, OTP, Password Reset, Biometric Setup
│   │   ├── calendar/   # Calendar views and event controllers
│   │   └── home/       # Dashboard, HR Portal (Attendance Punch), and Main Tabs
│   ├── routes/         # Routing management (AppPages, AppRoutes)
│   ├── services/       # Core services (ApiService, NotificationService, PermissionService)
│   └── translations/   # Localization files mapping keys to English and Arabic strings
└── main.dart           # Entry point, global initialization, and root GetMaterialApp
```
- **Business Logic:** Resides entirely within the `controllers` folders of each module.
- **UI Logic:** Found in the `views` folders.
- **API Layer:** The `services/api_service.dart` handles base configurations, while specific API calls are orchestrated within the respective module's Controller.

## 5. State Management
- **Solution:** GetX.
- **Handling:** Reactive state management is used exclusively. Variables are declared with `.obs` (e.g., `RxBool isLoading = false.obs;`), and the UI listens to these changes using the `Obx(() => ...)` widget.
- **Dependency Injection:** Controllers are loaded lazily into memory via GetX Bindings (`Get.lazyPut()`). This prevents memory bloat by only initializing controllers when their corresponding route is accessed.
- **Rebuild Optimization:** GetX inherently optimizes rebuilds by only redrawing the specific `Obx` widget whose observable value has changed, completely avoiding massive widget tree rebuilds.

## 6. Navigation Flow
The application utilizes GetX's built-in routing system (`GetPage`).
- **Startup:** The `MyApp._getInitialRoute()` function determines the initial screen. It checks if first-time permissions are needed and routes to `PermissionRequestView`.
- **Authentication Routing:** It verifies session status via `GetStorage`. Unauthenticated users land on `InstanceScanView` to scan their organization's QR code.
- **Biometric Flow:** If an active session exists and biometrics are enabled, the user is routed to `BiometricCheckView` for secure entry.
- **Main App:** Authenticated users enter the `HomeView`, which implements a `BottomNavigationBar` controlling the visibility of different tab views (Home, Attendance, Profile, Notifications, Calendar, Settings).

## 7. Features & Modules
### 7.1. Authentication Module
- **Purpose:** Secure multi-tenant access to the app.
- **Flow:** QR Instance Scan -> Domain Validation -> Email verification -> OTP/Password validation -> Biometric linkage.
- **Logic:** Handled by `AuthController`. Validates instances and manages password state.

### 7.2. Home / Dashboard Module
- **Purpose:** The central hub displaying employee stats and quick actions.
- **Flow:** The `HomeController` fetches dashboard metrics, attendance rates, and employee details via `GetHomeData` API.
- **Features:** It includes a background polling mechanism (`_pollForNotifications`) that pings for new alerts every 2 minutes.

### 7.3. HR Portal (Attendance) Module
- **Purpose:** Geo-fenced, verified attendance marking.
- **Flow:** User clicks "Punch". The `HrPortalController` checks permissions, retrieves high-accuracy GPS coordinates via `Geolocator`, and initializes the front camera. The user captures a selfie, and a payload (Image Base64, Lat/Lng, Device ID) is sent via the `MarkAttendance` API.
- **Logic:** Includes complex error handling and buffer resets for Android camera initialization.

### 7.4. Notifications Module
- **Purpose:** Company alerts and updates.
- **State Handling:** Integrated with `flutter_local_notifications`. When the `HomeController` detects a new notification from the polling API, it triggers a local push alert to the device tray.

## 8. API Integration
- **Architecture:** A centralized `ApiService` acts as a singleton providing a configured `Dio` client.
- **Base Structure:** Endpoints use the standard format `https://auto.resourceplus.app/Mobile/api/[Module]/[Endpoint]`.
- **Request Handling:** Query parameters like `instanceName`, `usrEmail`, and `Lang` are routinely passed to support multi-tenancy and localization.
- **Security Bypass (Dev):** A custom `IOHttpClientAdapter` currently allows expired SSL certificates for development/testing environments.

## 9. Local Storage & Persistence
- **Solution:** `GetStorage`.
- **Session Data:** Stores core identifiers (`email`, `username`, `empDisplayName`, `instanceName`, `password`) to maintain sessions.
- **Configurations:** Maintains application preferences such as Biometric opt-in (`biometricEnabled`), Notification Polling rules, and active application Language.

## 10. Reusable Components & Utilities
- **Theme Handling:** Configured globally in `main.dart` with robust Light and Dark mode `ThemeData`. Uses a consistent brand palette (Blue `#3B6EA5`, Green `#6BC04B`, Orange `#F7941D`).
- **Localization:** `AppTranslations` mapped to a `LanguageController` provides real-time switching between English (LTR) and Arabic (RTL).
- **Utility Services:** `NotificationService` handles the complex OS-level setup for local push alerts, while `PermissionService` handles graceful requests for device capabilities.

## 11. Build & Environment Configuration
- **Environment:** Flutter SDK constraint is set to `>=3.8.1`.
- **Android Setup:** Requires specific `AndroidManifest.xml` permissions for `CAMERA`, `ACCESS_FINE_LOCATION`, and `USE_BIOMETRIC`.
- **iOS Setup:** Requires `Info.plist` usage descriptions for Location (`NSLocationWhenInUseUsageDescription`), Camera (`NSCameraUsageDescription`), and FaceID (`NSFaceIDUsageDescription`).

## 12. Dependency Overview
- `dio`: High-performance HTTP networking.
- `get`: Complete state, dependency, and route management ecosystem.
- `mobile_scanner`: Enables the unique multi-tenant QR code login capability.
- `local_auth`: Implements secure OS-level biometric integrations.
- `geolocator`: Critical for HR portal location verification.
- `camera`: Used for capturing attendance selfies.

## 13. Security & Best Practices
- **Biometric Enforcement:** Provides a robust security layer for active sessions.
- **Anti-Spoofing:** Attendance payloads capture and transmit the physical `deviceId` and OS name to prevent account sharing or device spoofing.
- **Location Verification:** Attendance cannot be marked without valid, high-accuracy GPS coordinates.

## 14. Performance Optimizations
- **Camera Memory Management:** The camera is initialized with `ResolutionPreset.low` and captures strictly in JPEG format. This drastically reduces memory buffer size and prevents out-of-memory crashes on lower-end Android devices during attendance marking.
- **Targeted Rebuilds:** The strict usage of `Obx` ensures that only micro-components (like a specific text field or counter) rebuild, preserving 60/120fps UI rendering.
- **Lazy Instantiation:** Controllers are loaded lazily, ensuring RAM is only consumed when a user actively enters a specific module.

## 15. Known Limitations or Technical Notes
- **SSL Certificate Handling:** The `ApiService` currently contains code that bypasses SSL validation (`client.badCertificateCallback = ...`). **CRITICAL:** This must be conditionally removed or properly validated before a production App Store/Play Store release.
- **Camera Buffer Bottlenecks:** The `HrPortalController` contains manual `Future.delayed` blocks to handle specific Android camera buffer exceptions. Refactoring to the latest stable camera plugin might resolve these hardware-specific quirks.
- **Static Content Handling:** Some dashboard data relies on a heavy `StaticContents` array returned by the API which requires manual looping and parsing inside `HomeController`.

## 16. Deployment & Release Process
- **Android (APK/AAB):** Run `flutter build appbundle --release`. Ensure the Keystore is properly referenced in `android/app/build.gradle`.
- **iOS (IPA):** Run `flutter build ipa --release`. Ensure the Apple Developer provisioning profiles are properly linked in Xcode, and all `Info.plist` permission strings are human-readable for App Store Review guidelines.

## 17. Maintenance Notes
- **Architectural Rules:** Future developers must strictly use GetX bindings for dependency injection. Do not instantiate controllers globally using `Get.put()` outside of the main root unless absolutely necessary.
- **Localization Updates:** Any new hardcoded UI string must be added to the `AppTranslations` map to prevent breaking the Arabic/English toggle.
- **API Scalability:** When adding new API endpoints, ensure `instanceName`, `usrEmail`, and `Lang` are always included as query parameters, as the multi-tenant backend requires them for context resolution.

***

# Executive Summary
**Resource Plus** is a fully functional, enterprise-grade mobile Human Resources portal. It is designed to provide employees with a seamless, modern interface to manage their daily work requirements. Key business value drivers include a highly secure multi-tenant login system (allowing different companies to use the same app via unique QR codes), verified attendance punching that utilizes both GPS location tracking and selfie capture to prevent fraud, and biometric security integration. The application is polished, supports both English and Arabic languages natively, and is structurally prepared for scalable future updates.

# Technical Summary
The application is built on **Flutter** utilizing **GetX** as the primary architectural backbone for state management, routing, and dependency injection. The codebase strictly adheres to a modular, feature-first structure ensuring high maintainability. Networking is handled securely via **Dio**, and local session data is persisted via **GetStorage**. Key technical implementations include a robust camera buffer management system for low-end devices during attendance tracking, real-time background notification polling, and OS-level biometric integration. The project is production-ready, noting only a requirement to enforce strict SSL validation in the `ApiService` prior to final store deployment.

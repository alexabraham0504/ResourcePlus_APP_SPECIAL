# Google Calendar Integration Setup Guide

This guide explains how to set up Google Calendar integration in the Resource Plus app.

## Overview

The app now includes a Calendar tab that allows users to:
- Connect to their Google Calendar account
- View calendar events
- Create new events
- Edit existing events
- Delete events
- View today's schedule

## Prerequisites

1. A Google Cloud Console account
2. Flutter development environment
3. Android/iOS development setup

## Step 1: Google Cloud Console Setup

### 1.1 Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note down your Project ID

### 1.2 Enable Google Calendar API

1. In the Google Cloud Console, go to "APIs & Services" > "Library"
2. Search for "Google Calendar API"
3. Click on it and press "Enable"

### 1.3 Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth 2.0 Client IDs"
3. Choose "Android" as the application type
4. Fill in the following details:
   - **Package name**: `com.resourceplus.app`
   - **SHA-1 certificate fingerprint**: (see instructions below)

### 1.4 Get SHA-1 Fingerprint

#### For Debug Builds:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### For Release Builds:
```bash
keytool -list -v -keystore your-release-keystore.jks -alias your-key-alias
```

### 1.5 Configure OAuth Consent Screen

1. Go to "APIs & Services" > "OAuth consent screen"
2. Choose "External" user type
3. Fill in the required information:
   - App name: "Resource Plus"
   - User support email: Your email
   - Developer contact information: Your email
4. Add the following scopes:
   - `https://www.googleapis.com/auth/calendar.readonly`
   - `https://www.googleapis.com/auth/calendar.events`

## Step 2: Update App Configuration

### 2.1 Update Google Auth Config

Edit `lib/app/config/google_auth_config.dart` and replace the placeholder values:

```dart
class GoogleAuthConfig {
  static const String androidClientId = 'YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com';
  // ... other configurations
}
```

### 2.2 Update Calendar Service

Edit `lib/app/services/calendar_service.dart` and update the client ID:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: _scopes,
  clientId: 'YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com',
);
```

## Step 3: Android Configuration

### 3.1 Update AndroidManifest.xml

The manifest already includes the necessary OAuth callback configuration:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.resourceplus.app" />
</intent-filter>
```

### 3.2 Update build.gradle (if needed)

If you're using a different package name, update it in:
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- OAuth client configuration

## Step 4: iOS Configuration (Optional)

If you plan to support iOS:

### 4.1 Update Info.plist

Add URL schemes to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.resourceplus.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.resourceplus.app</string>
        </array>
    </dict>
</array>
```

### 4.2 Create iOS OAuth Client

1. In Google Cloud Console, create another OAuth 2.0 Client ID
2. Choose "iOS" as the application type
3. Add your iOS bundle identifier
4. Update the configuration with the iOS client ID

## Step 5: Testing the Integration

### 5.1 Build and Run

1. Run `flutter pub get` to install dependencies
2. Build and run the app: `flutter run`

### 5.2 Test Calendar Features

1. Navigate to the Calendar tab
2. Tap "Connect" to sign in with Google
3. Grant calendar permissions
4. Test viewing, creating, editing, and deleting events

## Troubleshooting

### Common Issues

1. **"Sign in failed" error**
   - Check that your OAuth client ID is correct
   - Verify SHA-1 fingerprint matches your keystore
   - Ensure Google Calendar API is enabled

2. **"Access denied" error**
   - Check OAuth consent screen configuration
   - Verify scopes are properly configured
   - Ensure the app is in testing or published

3. **Events not loading**
   - Check internet connection
   - Verify user has granted calendar permissions
   - Check Google Calendar API quotas

### Debug Information

Enable debug logging by adding this to your code:

```dart
print('Google Sign-In Debug: ${account?.email}');
print('Access Token: ${auth.accessToken}');
```

## Security Considerations

1. **Never commit OAuth credentials to version control**
2. **Use different client IDs for debug and release builds**
3. **Implement proper token refresh handling**
4. **Consider implementing server-side token validation**

## API Quotas and Limits

- Google Calendar API has daily quotas
- Monitor usage in Google Cloud Console
- Implement proper error handling for quota exceeded errors

## Support

For issues with:
- **Google Cloud Console**: Check Google's documentation
- **Flutter/App issues**: Check the app logs and error messages
- **OAuth configuration**: Verify all steps in this guide

## Next Steps

After successful setup, consider:
1. Adding calendar sync with other providers (Outlook, Apple Calendar)
2. Implementing calendar event notifications
3. Adding calendar sharing features
4. Implementing offline calendar support 
// Google Sign-In Configuration
//
// To use Google Sign-In with Google Calendar API:
// 1. Go to Google Cloud Console (https://console.cloud.google.com/)
// 2. Create a new project or select an existing one
// 3. Enable the Google Calendar API
// 4. Go to "Credentials" and create an OAuth 2.0 Client ID
// 5. Add your Android package name and SHA-1 fingerprint
// 6. Replace the placeholder values below with your actual credentials

class GoogleAuthConfig {
  // Android OAuth 2.0 Client ID
  // Format: xxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
  static const String androidClientId =
      '494571613065-s24ibflsmpniku44sfa9tkbi2gdk0hj2.apps.googleusercontent.com';

  // iOS OAuth 2.0 Client ID (if needed)
  // Format: xxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
  static const String iosClientId =
      'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

  // Web OAuth 2.0 Client ID (if needed)
  // Format: xxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
  static const String webClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  // OAuth 2.0 Client Secret (for server-side operations)
  static const String clientSecret = 'YOUR_CLIENT_SECRET';

  // Scopes required for Google Calendar API
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar.events',
  ];

  // Redirect URI for OAuth callback
  static const String redirectUri = 'com.resourceplus.app:/oauth2redirect';
}

// Instructions for setting up Google Sign-In:
//
// 1. Android Setup:
//    - Add your SHA-1 fingerprint to the OAuth 2.0 client ID
//    - Get SHA-1: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
//
// 2. iOS Setup (if needed):
//    - Add your iOS bundle identifier to the OAuth 2.0 client ID
//    - Configure URL schemes in Info.plist
//
// 3. Update the credentials above with your actual values
//
// 4. Test the integration by running the app and trying to connect to Google Calendar

# iOS Build Guide for Resource Plus ESS

This guide outlines the standard operating procedures for building the iOS version of the Resource Plus application.

## Prerequisites
- A Mac running macOS with Xcode installed.
- CocoaPods installed (`sudo gem install cocoapods`).
- The developer's Apple ID (with the `GPS37JXSWW` team) must be signed into Xcode via **Xcode > Settings > Accounts**.

## Local Simulator Builds
To test the application quickly on a local iOS Simulator:

1. Ensure your Flutter environment is clean and dependencies are up to date:
   ```bash
   flutter clean
   flutter pub get
   ```
2. Navigate to the `ios` folder, update specs, and install Pods:
   ```bash
   cd ios
   rm -rf Pods/ Podfile.lock .symlinks/
   pod repo update
   pod install
   cd ..
   ```
3. Build and run on a Simulator:
   ```bash
   # Open an iOS simulator first, or let Flutter launch the default one
   flutter run -d simulator
   ```
   *Alternatively, to just build the `.app` bundle:*
   ```bash
   flutter build ios --simulator
   ```

## Production IPA Generation
To generate an `.ipa` file suitable for uploading to TestFlight or the App Store (requires a Mac):

1. Run the clean and pod install steps as shown above.
2. Build the IPA using the newly created `ExportOptions.plist`:
   ```bash
   flutter build ipa --export-options-plist=ios/ExportOptions.plist
   ```
3. The resulting `.ipa` file will be located in:
   `build/ios/ipa/`
4. Use the **Transporter** app (available on the Mac App Store) or `xcrun altool` to upload the `.ipa` to App Store Connect.

## Troubleshooting
- **Pod Install Errors**: If `pod install` fails, try running `pod repo update` or deleting `~/.cocoapods/repos/trunk`.
- **Code Signing Errors**: Ensure you have a valid provisioning profile for `com.resourceplus.app` and that your Apple ID is selected in the Xcode project runner settings under the "Signing & Capabilities" tab.

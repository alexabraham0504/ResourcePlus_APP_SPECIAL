# Update Flow Investigation Summary

## Observed Behavior & Navigation Flow
When testing the update flow from the mandatory update screen, tapping "Update Now" correctly initializes the Google Play Core in-app update overlay. If the user decides to cancel this in-app update by pressing the device's physical back button, the overlay is dismissed. However, immediately after dismissal, the application forcefully opens the external Google Play Store app. 

When the user presses the physical back button again to exit the external Play Store and return to the application, they successfully arrive back at the blocked update screen. At this precise moment, the application detects that it has resumed from the background and automatically triggers the update check again. This causes the Play Core in-app update overlay to immediately pop up over the screen without the user tapping anything. 

Additionally, if the user dismisses all overlays and attempts to press the physical back button directly on the update screen, the application correctly ignores the input. It does not return to the previous screen or the dashboard, successfully maintaining the blocked state. Tapping the "Update Now" button again correctly restarts the process and navigates to the update destination.

## Unexpected Behavior & UX Problems
While the core security requirement of blocking the user is functioning as intended, the flow suffers from significant UX problems and an aggressive navigation loop. 

The primary issue is a "double-launch" defect. By sequentially triggering the in-app update and then the external Play Store, the app creates a jarring experience where canceling one update method forcefully pushes the user into another. Furthermore, the aggressive auto-loop created by the lifecycle resume event traps the user. Whenever they return to the app from the external store, they are instantly confronted with the in-app update overlay again, creating a frustrating cycle that is difficult to escape gracefully.

## Likely Causes
These issues stem from two specific implementation details in the current codebase. First, the primary action button on the update screen executes two asynchronous commands in sequence: it awaits the result of the update check, and then unconditionally executes the command to open the external Play Store. Because the service internally handles and swallows the cancellation of the in-app update, the execution flow continues directly to the external fallback.

Second, the update service actively listens to the application lifecycle. Whenever the app enters the resumed state, it unconditionally runs the update check. Because the update check logic is configured to automatically launch the immediate update overlay if an update is available, returning from the background guarantees the overlay will reappear.

## Recommended Fixes
To resolve the double-launch issue, the fallback logic should be separated. The primary button should only initiate the update check. The logic to open the external Play Store should be moved exclusively into the service's error handling block, ensuring it only triggers if the Play Core API legitimately fails or is unavailable, rather than when a user simply cancels.

To fix the aggressive auto-loop, the lifecycle resume event should be modified. While it is important to silently re-verify the update status in the background when the app resumes, it should not automatically invoke the intrusive Play Core overlay if the user is already parked on the dedicated update screen. The overlay should require explicit user intent, such as tapping the update button again.

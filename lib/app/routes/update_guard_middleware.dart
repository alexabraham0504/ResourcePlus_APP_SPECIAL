import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/app_update_service.dart';
import '../routes/app_routes.dart';

class UpdateGuardMiddleware extends GetMiddleware {
  // Priority 1 ensures this runs before auth guards
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    try {
      // If the update service is registered and an update is required,
      // block any navigation to protected routes and redirect to the update screen.
      final updateService = Get.find<AppUpdateService>();
      if (updateService.isUpdateRequired.value) {
        if (route != AppRoutes.updateRequired) {
          debugPrint('UpdateGuardMiddleware: Blocked navigation to $route. Redirecting to UpdateRequiredView.');
          return const RouteSettings(name: AppRoutes.updateRequired);
        }
      }
    } catch (_) {
      // AppUpdateService not yet injected (e.g. at very early startup)
      // It handles its own startup checks, so we allow this for now.
    }
    
    return null; // Proceed as normal
  }
}

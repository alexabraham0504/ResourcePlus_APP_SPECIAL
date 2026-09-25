import 'package:get/get.dart';
import '../controllers/face_enrollment_controller.dart';

class FaceEnrollmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FaceEnrollmentController>(
      () => FaceEnrollmentController(),
    );
  }
}

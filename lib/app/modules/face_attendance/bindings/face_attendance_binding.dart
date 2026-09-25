import 'package:get/get.dart';
import '../controllers/face_attendance_controller.dart';

class FaceAttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FaceAttendanceController>(
      () => FaceAttendanceController(),
    );
  }
}

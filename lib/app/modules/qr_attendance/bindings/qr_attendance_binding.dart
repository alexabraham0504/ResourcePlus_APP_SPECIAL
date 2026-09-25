import 'package:get/get.dart';
import '../controllers/qr_attendance_controller.dart';

class QRAttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<QRAttendanceController>(() => QRAttendanceController());
  }
}

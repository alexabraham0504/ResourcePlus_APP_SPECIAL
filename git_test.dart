import 'dart:io';

void main() async {
  try {
    var result = await Process.run('git', ['show', 'HEAD@{1.day.ago}:lib/app/modules/home/controllers/home_controller.dart']);
    File('home_controller_old.dart').writeAsStringSync(result.stdout.toString());
    print('Wrote old home_controller.dart to home_controller_old.dart');
  } catch (e) {
    print('Error: $e');
  }
}

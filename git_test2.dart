import 'dart:io';

void main() async {
  try {
    var result = await Process.run('git', ['log', '-p', '-2', '--', 'lib/app/modules/auth/controllers/auth_controller.dart']);
    File('auth_controller_diff.txt').writeAsStringSync(result.stdout.toString());
    print('Wrote auth_controller diff to auth_controller_diff.txt');
  } catch (e) {
    print('Error: $e');
  }
}

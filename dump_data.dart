import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  await GetStorage.init();
  final box = GetStorage();
  final data = box.read('cachedAttendanceData');
  if (data != null) {
    File('att_data_dump.json').writeAsStringSync(jsonEncode(data));
    print('Dumped to att_data_dump.json');
  } else {
    print('No cached data found.');
  }
}

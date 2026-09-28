class ApiEndpoints {
  static const String baseUrl = 'https://app.resourceplus.app';

  // Master Endpoints
  static const String checkInstance = '$baseUrl/Mobile/api/Master/checkInstance';
  static const String getSupportURL = '$baseUrl/mobile/api/Master/GetSupportURL';

  // Client (Auth) Endpoints
  static const String checkEmail = '$baseUrl/Mobile/api/Client/CheckEmail';
  static const String verifyOtp = '$baseUrl/Mobile/api/Client/VerifyOtp';
  static const String validateUser = '$baseUrl/Mobile/api/Client/ValidateUser';
  static const String changePwd = '$baseUrl/Mobile/api/Client/ChangePwd';
  static const String getPortalUrl = '$baseUrl/Mobile/api/Client/GetPortalUrl';
  static const String updateDeviceToken = '$baseUrl/Mobile/api/Client/UpdateDeviceToken';

  // Client (Home/Dashboard) Endpoints
  static const String getHomeData = '$baseUrl/Mobile/api/Client/GetHomeData';
  static const String getAttData = '$baseUrl/Mobile/api/Client/GetAttData';
  static const String getAttendancePunchData = '$baseUrl/Mobile/api/Client/GetAttendancePunchData';
  static const String getProfileData = '$baseUrl/Mobile/api/Client/GetProfileData';
  static const String getNotifcnData = '$baseUrl/Mobile/api/Client/GetNotifcnData';
  // static const String updateReadStatus = '$baseUrl/Mobile/api/Client/UpdateReadStatus';

  static const String getSettingsData = '$baseUrl/Mobile/api/Client/GetSettingsData';
  static const String getProfPicture = '$baseUrl/Mobile/api/Client/GetProfPicture';

  // Client (HR Portal/Attendance) Endpoints
  static const String getLastFivePunches = '$baseUrl/Mobile/api/Client/GetLastFivePunches';
  static const String getShiftDetails = '$baseUrl/Mobile/api/Client/GetShiftDetails';
  static const String markAttendance = '$baseUrl/Mobile/api/Client/MarkAttendance';
  static const String markAttendancev2 = '$baseUrl/Mobile/api/Client/MarkAttendancev2';

  // ── Biometric API Endpoints (RplusWebAPIV2 / ClientController) ─────────────
  static const String biometricBaseUrl = '$baseUrl/Mobile/api';

  // Face Template — Enroll + Retrieve
  // POST /Mobile/api/FaceEnroll?instanceName={instanceName}
  // Body: { usrEmail, embedding: [...], modelVersion, templateVersion }
  static const String faceEnroll = '$biometricBaseUrl/FaceEnroll';

  // GET /Mobile/api/FaceTemplate?usrEmail={usrEmail}&instanceName={instanceName}
  static const String faceGetTemplate = '$biometricBaseUrl/FaceTemplate';

  // Bluetooth Beacons — list authorized beacons per employee
  // GET /Mobile/api/Attendance/Bluetooth/Beacons?instanceName={instanceName}&usrEmail={usrEmail}
  static const String bluetoothBeacons = '$biometricBaseUrl/Attendance/Bluetooth/Beacons';

  // Bluetooth Device Register — bind device to employee account
  // POST /Mobile/api/Attendance/Bluetooth/Register?instanceName={instanceName}
  // Body: { usrEmail, deviceIdentifier }
  static const String bluetoothRegister = '$biometricBaseUrl/Attendance/Bluetooth/Register';
  
  // GET /Mobile/api/Bluetooth/CheckRegistration?instanceName={instanceName}
  static const String bluetoothCheckRegistration = '$biometricBaseUrl/Bluetooth/CheckRegistration';
}

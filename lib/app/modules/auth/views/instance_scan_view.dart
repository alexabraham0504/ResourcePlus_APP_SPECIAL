import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class InstanceScanView extends StatefulWidget {
  const InstanceScanView({super.key});

  @override
  State<InstanceScanView> createState() => _InstanceScanViewState();
}

class _InstanceScanViewState extends State<InstanceScanView> {
  final AuthController controller = Get.put(AuthController());
  late final TextEditingController instanceController;

  @override
  void initState() {
    super.initState();
    instanceController = TextEditingController();
  }

  @override
  void dispose() {
    instanceController.dispose();
    super.dispose();
  }
  final blue = const Color(0xFF3B6EA5);
  final green = const Color(0xFF6BC04B);
  final orange = const Color(0xFFF7941D);

  void _openQrScanner() async {
    final result = await Get.to<String>(() => const QrScannerScreen());
    if (result != null && result.isNotEmpty) {
      setState(() {
        instanceController.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Image.asset(
                  'assets/app_logo.png',
                  height: 80,
                  width: 280,
                ),
              ),
              Card(
                elevation: 8,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'instance_scan'.tr,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: instanceController,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'instance_name'.tr,
                                prefixIcon: Icon(
                                  Icons.domain,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _openQrScanner,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  color: theme.colorScheme.primary,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => controller.errorMessage.value.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  controller.errorMessage.value,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => controller.isLoading.value
                            ? CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final instance =
                                        instanceController.text.trim();
                                    if (instance.isEmpty) {
                                      controller.errorMessage.value = 'Please enter an instance name';
                                      Get.snackbar(
                                        'Error',
                                        'Please enter an instance name',
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        colorText: theme.colorScheme.onError,
                                      );
                                      return;
                                    }
                                    controller.errorMessage.value = '';
                                    final valid = await controller
                                        .validateInstance(instance);
                                    if (valid) {
                                      controller.instanceName.value = instance;
                                      Get.toNamed(AppRoutes.emailVerification);
                                    } else {
                                      // Error message is shown above button
                                      Get.snackbar(
                                        'Error',
                                        controller.errorMessage.value.isNotEmpty
                                            ? controller.errorMessage.value
                                            : 'Invalid instance name',
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        colorText: theme.colorScheme.onError,
                                      );
                                    }
                                  },
                                  child: Text('continue'.tr),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _scanned = false;
  late MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Scan QR Code',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (!_scanned &&
                  barcodes.isNotEmpty &&
                  barcodes.first.rawValue != null) {
                setState(() => _scanned = true);
                Get.back(result: barcodes.first.rawValue);
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: const Text(
                'Align the QR code within the frame to scan.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../webview_page.dart';

class SelfServiceTab extends StatefulWidget {
  const SelfServiceTab({super.key});

  @override
  State<SelfServiceTab> createState() => _SelfServiceTabState();
}

class _SelfServiceTabState extends State<SelfServiceTab> {
  final controller = Get.find<HomeController>();
  bool _wasActive = false;
  int _activationCount = 0;
  bool _isFetching = false;

  Future<void> _fetchUrl() async {
    if (_isFetching) return;
    setState(() => _isFetching = true);
    await controller.preFetchPortalUrl();
    if (mounted) setState(() => _isFetching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.currentIndex.value == 2;
      
      if (isActive && !_wasActive) {
        // We just navigated to this tab, increment count to force a fresh load
        _activationCount++;
        
        // Force clear the URL so it generates a fresh token every time!
        // The old URL might have an expired session token!
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.cachedPortalUrl.value = '';
          _fetchUrl();
        });
      }
      
      _wasActive = isActive;

      if (_activationCount == 0) {
        // Tab hasn't been visited yet
        return const SizedBox.shrink();
      }

      final url = controller.cachedPortalUrl.value;
      
      if (url.isEmpty) {
        return Center(
          child: _isFetching 
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('network_error_check_connection'.tr, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fetchUrl,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text('retry'.tr),
                  ),
                ],
              ),
        );
      }
      
      return WebViewPage(
        key: ValueKey('self_service_tab_$_activationCount'),
        url: controller.appendLangToUrl(url),
        title: 'self_service'.tr,
        isEmbedded: true,
      );
    });
  }
}


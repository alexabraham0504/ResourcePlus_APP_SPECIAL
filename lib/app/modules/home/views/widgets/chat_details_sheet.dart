import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../orbit_chat_screen.dart';
import '../tabs/attendance_tab.dart';
import '../tabs/notification_tab.dart';
import '../webview_page.dart';
import 'tab_header.dart';

class ResourcePlusChatHeader extends StatelessWidget {
  const ResourcePlusChatHeader({super.key, required this.onNotifications});
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TabHeader(
        title: 'ResourcePlus AI',
        onNotificationTap: onNotifications,
      ),
    ),
  );
}

/// Opens details above the chat rather than switching the home tab, preserving
/// its BLoC, scroll position and unsent message.
Future<void> showChatDetails(
  BuildContext context,
  ChatShortcut shortcut,
) async {
  final controller = Get.find<HomeController>();
  if (shortcut == ChatShortcut.attendance) {
    controller.fetchAttendanceData(silent: true);
  } else if (shortcut == ChatShortcut.notifications) {
    controller.fetchNotificationData();
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: .94,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shortcut.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Back to chat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (shortcut) {
              ChatShortcut.attendance => const AttendanceTab(),
              ChatShortcut.notifications => const NotificationTab(),
              _ => _ChatPortalDetails(shortcut: shortcut),
            },
          ),
        ],
      ),
    ),
  );
}

/// The repository exposes one authenticated self-service URL, not separate
/// leave/request/approval deep links. Keep that limitation visible in the UI.
class _ChatPortalDetails extends StatefulWidget {
  const _ChatPortalDetails({required this.shortcut});
  final ChatShortcut shortcut;

  @override
  State<_ChatPortalDetails> createState() => _ChatPortalDetailsState();
}

class _ChatPortalDetailsState extends State<_ChatPortalDetails> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = _load();
  }

  Future<String> _load() async {
    final controller = Get.find<HomeController>();
    controller.cachedPortalUrl.value = '';
    await controller.preFetchPortalUrl();
    final url = controller.cachedPortalUrl.value;
    if (url.isEmpty) throw StateError('Self-service is unavailable');
    return controller.appendLangToUrl(url);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text(
          'Choose ${widget.shortcut.label} in your self-service portal.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      Expanded(
        child: FutureBuilder<String>(
          future: _url,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to open self-service.'),
                    TextButton(
                      onPressed: () => setState(() => _url = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return WebViewPage(
              url: snapshot.data!,
              title: widget.shortcut.label,
            );
          },
        ),
      ),
    ],
  );
}

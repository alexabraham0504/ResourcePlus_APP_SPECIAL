import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_plus/app/modules/home/views/orbit_chat_screen.dart';
import 'package:resourceplus_app/models/chat_message.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:resource_plus/app/modules/home/controllers/home_controller.dart';
import 'package:resource_plus/app/controllers/global_beacon_controller.dart';
import 'package:resource_plus/app/controllers/language_controller.dart';
import 'package:resource_plus/app/modules/home/views/widgets/chat_details_sheet.dart';
import 'package:resource_plus/app/modules/home/views/tabs/ai_chat_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resource_plus/app/modules/home/views/widgets/home_bottom_navigation.dart';
import 'package:resource_plus/app/translations/app_translations.dart';

class _PreviewHome extends HomeController {
  @override
  // Suppress backend startup in this isolated widget fixture.
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> fetchAttendanceData({bool silent = false}) async {}
  @override
  Future<void> fetchNotificationData({bool silent = false}) async {}
}

class _PreviewBeacon extends GlobalBeaconController {
  @override
  // Suppress native Bluetooth subscriptions in widget tests.
  // ignore: must_call_super
  void onInit() {}
}

class _PreviewLanguage extends LanguageController {
  @override
  // Keep the preview locale fixed without triggering app refreshes.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = GlobalKey();
  setUp(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('en', 'US');
    Get.put<HomeController>(_PreviewHome());
    Get.put<GlobalBeaconController>(_PreviewBeacon());
    Get.put<LanguageController>(_PreviewLanguage());
  });
  tearDown(() => Get.reset());

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double scale = 1,
    List<ChatMessage> messages = const [],
    ValueChanged<String>? onSend,
    ValueChanged<ChatShortcut>? onQuickAccess,
    ValueChanged<int>? onNavigate,
    bool busy = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'OrbitPreview'),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(
            key: capture,
            child: Scaffold(
              bottomNavigationBar: HomeBottomNavigation(
                currentIndex: 6,
                onTap: onNavigate ?? (_) {},
              ),
              body: OrbitChatPage(
                appHeader: ResourcePlusChatHeader(onNotifications: () {}),
                messages: messages,
                busy: busy,
                onSend: onSend ?? (_) {},
                onQuickAccess: onQuickAccess ?? (_) {},
                onBack: () {},
                onSettings: () {},
                onClear: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/app_logo.png'),
        capture.currentContext!,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snapshot(String name) async {
    if (!const bool.fromEnvironment('ORBIT_PREVIEW')) return;
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('design/orbit').create(recursive: true);
    await File(
      'design/orbit/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  }

  setUpAll(() async {
    final storageDirectory = await Directory.systemTemp.createTemp(
      'resourceplus-chat-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storageDirectory.path,
        );
    await GetStorage.init();
    if (const bool.fromEnvironment('ORBIT_PREVIEW')) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('OrbitPreview')
          ..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
        await loader.load();
      }
    }
  });

  testWidgets(
    'welcome, voice and populated conversation render without overflow',
    (tester) async {
      await mount(tester);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => snapshot('orbit-chat'));
      await tester.tap(find.text('Voice'));
      await tester.pumpAndSettle();
      expect(find.text('Tap to speak'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => snapshot('orbit-voice'));
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      await mount(
        tester,
        messages: [
          ChatMessage.user(content: 'Help me find a little more focus today.'),
          ChatMessage.assistant(
            content:
                'Let’s make a little room for what matters.\n\n**Your next 30 minutes**\n\n1. Choose one task worth finishing.\n2. Close the tabs you don’t need.\n3. Work for 25 minutes, then take a breath.\n\nWhat’s the one thing you’d love to move forward?',
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => snapshot('orbit-conversation'));
    },
  );

  testWidgets(
    'production AI chat tab supplies its required quick-access callback',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AIChatTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrbitChatScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey(ChatShortcut.attendance)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('prompt remains editable and send submits once', (tester) async {
    final sent = <String>[];
    await mount(tester, onSend: sent.add);
    await tester.ensureVisible(find.text('Find my spark'));
    await tester.tap(find.text('Find my spark'));
    await tester.pump();
    expect(sent, isEmpty);
    await tester.enterText(find.byType(TextField), 'My own idea');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    expect(sent, ['My own idea']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.byTooltip('Send message'));
    expect(sent.length, 1);
  });

  testWidgets('small screens and large text fit; busy state blocks sending', (
    tester,
  ) async {
    await mount(tester, width: 320, scale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Voice'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await mount(tester, busy: true);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Send message',
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'all shortcuts remain one tap away during replies and preserve the draft',
    (tester) async {
      final selected = <ChatShortcut>[];
      await mount(
        tester,
        busy: false,
        onQuickAccess: selected.add,
        messages: [ChatMessage.user(content: 'My ongoing conversation')],
      );
      await tester.enterText(
        find.byType(TextField),
        'Keep my unfinished message',
      );
      for (final shortcut in ChatShortcut.values) {
        await tester.tap(find.byKey(ValueKey(shortcut)));
        await tester.pump();
      }
      expect(selected, ChatShortcut.values);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep my unfinished message',
      );
      expect(find.text('My ongoing conversation'), findsOneWidget);
      await mount(
        tester,
        busy: true,
        onQuickAccess: selected.add,
        messages: [ChatMessage.typing()],
      );
      await tester.tap(find.byKey(const ValueKey(ChatShortcut.attendance)));
      await tester.pump();
      expect(selected.last, ChatShortcut.attendance);
      expect(selected.length, 6);
    },
  );

  testWidgets(
    'closing notification details returns to the same chat and draft',
    (tester) async {
      await mount(
        tester,
        onQuickAccess: (shortcut) =>
            showChatDetails(capture.currentContext!, shortcut),
        messages: [ChatMessage.user(content: 'Keep this conversation')],
      );
      await tester.enterText(find.byType(TextField), 'Keep this draft');
      await tester.tap(find.byKey(const ValueKey(ChatShortcut.notifications)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to chat'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to chat'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep this draft',
      );
      expect(find.text('Keep this conversation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared bottom tabs remain visible below chat and dispatch navigation',
    (tester) async {
      final destinations = <int>[];
      await mount(
        tester,
        onNavigate: destinations.add,
        messages: [ChatMessage.user(content: 'An ongoing chat')],
      );
      final bar = find.byType(BottomNavigationBar);
      expect(bar, findsOneWidget);
      final items = tester.widget<BottomNavigationBar>(bar).items;
      expect(items.map((item) => item.label), [
        'Home',
        'Attendance',
        'SELF SERVICE',
        'Profile',
        'Settings',
      ]);
      for (final item in items) {
        await tester.tap(
          find.descendant(of: bar, matching: find.text(item.label!)),
        );
        await tester.pump();
      }
      expect(destinations, [0, 1, 2, 3, 4]);
      expect(
        tester.getBottomRight(find.byType(TextField)).dy,
        lessThan(tester.getTopLeft(bar).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all five shortcuts fit with reduced keyboard space', (
    tester,
  ) async {
    await mount(tester, width: 320, height: 480, scale: 1.5);
    for (final shortcut in ChatShortcut.values) {
      expect(find.byKey(ValueKey(shortcut)).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}

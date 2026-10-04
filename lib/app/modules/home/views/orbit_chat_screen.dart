import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:resourceplus_app/bloc/chat_bloc.dart';
import 'package:resourceplus_app/bloc/chat_event.dart';
import 'package:resourceplus_app/bloc/chat_state.dart';
import 'package:resourceplus_app/models/chat_message.dart';
import 'package:resourceplus_app/screens/settings_screen.dart';
import 'package:resourceplus_app/services/settings_service.dart';
import 'package:resourceplus_app/services/voice_websocket_service.dart';

const _ink = Color(0xFF173347);
const _blue = Color(0xFF004A77);
const _green = Color(0xFF087A62);
const _muted = Color(0xFF607889);

enum ChatShortcut {
  attendance('AT', 'Attendance'),
  leaveTravel('LT', 'Leave & Travel'),
  requests('RQ', 'Requests'),
  notifications('NT', 'Notifications'),
  approvals('MA', 'Manager Approvals');

  const ChatShortcut(this.code, this.label);
  final String code;
  final String label;
}

/// Adapter for the existing ResourcePlus chat service.
class OrbitChatScreen extends StatelessWidget {
  const OrbitChatScreen({
    super.key,
    required this.settingsService,
    required this.onQuickAccess,
    this.appHeader,
    this.onBackPressed,
  });
  final SettingsService settingsService;
  final ValueChanged<ChatShortcut> onQuickAccess;
  final Widget? appHeader;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) => BlocBuilder<ChatBloc, ChatState>(
    builder: (context, state) => OrbitChatPage(
      appHeader: appHeader,
      onQuickAccess: onQuickAccess,
      messages: state.messages,
      busy: state is ChatLoading,
      error: state is ChatError ? 'Couldn’t connect. Please try again.' : null,
      onSend: (text) => context.read<ChatBloc>().add(SendMessageEvent(text)),
      onRetry: () =>
          context.read<ChatBloc>().add(const RetryLastMessageEvent()),
      onClear: () => context.read<ChatBloc>().add(const ClearChatEvent()),
      onBack: onBackPressed ?? () => Navigator.of(context).maybePop(),
      onSettings: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(settingsService: settingsService),
        ),
      ),
    ),
  );
}

/// A responsive voice + text surface. Voice is transcribed into an editable
/// draft; only Send submits it. AI responses use the host's existing service.
class OrbitChatPage extends StatefulWidget {
  const OrbitChatPage({
    super.key,
    required this.onSend,
    required this.onBack,
    required this.onSettings,
    required this.onClear,
    required this.onRetry,
    required this.onQuickAccess,
    this.appHeader,
    this.messages = const [],
    this.busy = false,
    this.error,
  });
  final ValueChanged<String> onSend;
  final ValueChanged<ChatShortcut> onQuickAccess;
  final Widget? appHeader;
  final VoidCallback onBack, onSettings, onClear, onRetry;
  final List<ChatMessage> messages;
  final bool busy;
  final String? error;

  @override
  State<OrbitChatPage> createState() => _OrbitChatPageState();
}

class _OrbitChatPageState extends State<OrbitChatPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _voiceService = VoiceWebSocketService();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _motion;
  bool _voice = false, _listening = false, _starting = false;
  bool _showPinnedDock = false;
  String? _voiceError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    
    _initTts();

    _voiceService.messageStream.listen((data) {
      if (!mounted) return;
      _handleVoiceMessage(data);
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _handleVoiceMessage(Map<String, dynamic> data) {
    // Debug log
    print('VoiceWS Event: $data');

    final type = data['type'] as String?;

    switch (type) {

      // ── READY: backend connected and listening. Never show as chat bubble. ──
      case 'ready':
        // Backend is ready. PCM streaming starts automatically after this.
        // No UI bubble needed.
        break;

      // ── TRANSCRIPT_FINAL: what the user actually said (from STT) ──
      case 'transcript_final':
        final userText = data['transcript']?.toString() ?? data['text']?.toString() ?? '';
        if (userText.isNotEmpty) {
          context.read<ChatBloc>().add(AddMessageEvent(ChatMessage.user(content: userText)));
        }
        break;

      // ── PROCESSING: backend is thinking. Show spinner, no bubble. ──
      case 'listening': // Backend confirmed it is listening to our audio stream
      case 'processing':
        // No chat bubble needed for these control states.
        break;

      // ── ASSISTANT_TEXT: the AI's answer. Show immediately as a chat bubble. ──
      case 'assistant_text':
        final aiText = data['display_message']?.toString()
            ?? data['message']?.toString()
            ?? data['text']?.toString()
            ?? '';
        if (aiText.isNotEmpty) {
          final confirmationId = data['confirmation_id']?.toString();
          final List<String>? reasonOptions = data['reason_options'] != null
              ? List<String>.from(data['reason_options'])
              : null;
          context.read<ChatBloc>().add(AddMessageEvent(
            ChatMessage.assistant(
              content: aiText,
              confirmationId: confirmationId,
              reasonOptions: reasonOptions,
            ),
          ));
          // Backend will send {type: 'final', audio_base64: '...'} with the Azure TTS audio.
          // Do NOT read with Flutter TTS — wait for the backend audio in the 'final' event.
        }
        break;

      // ── FINAL: turn is complete. Play the backend Azure TTS audio. ──
      case 'final':
        // Do NOT add another assistant_text bubble — it was already added above.
        // Play the backend-generated Azure TTS audio (voice-optimized, short form)
        final audioBase64 = data['audio_base64'] as String?;
        if (audioBase64 != null && audioBase64.isNotEmpty) {
          _playBackendAudio(audioBase64).then((_) {
            // Dismiss overlay after audio finishes
            _stopListening();
            if (mounted) setState(() => _voice = false);
          });
        } else {
          // No audio from backend — just dismiss overlay
          _stopListening();
          if (mounted) setState(() => _voice = false);
        }
        break;

      // ── ERROR: something went wrong. Show a friendly message. ──
      case 'error':
        final errMsg = data['message']?.toString() ?? 'Voice is temporarily unavailable.';
        if (mounted) {
          setState(() {
            _voiceError = errMsg;
            _voice = false;
          });
        }
        _stopListening();
        break;

      // ── _WS_CLOSED: internal event we emit when the WebSocket closes ──
      case '_ws_closed':
        _stopListening();
        if (mounted) setState(() => _voice = false);
        break;

      // ── Unknown event types: log only, never show as a chat bubble ──
      default:
        print('VoiceWS: Unhandled event type "$type" — data: $data');
        break;
    }
  }

  /// Decodes the Azure TTS audio_base64 from the backend 'final' event
  /// and plays it. The backend sends a short, voice-optimized response —
  /// NOT the full markdown text shown in the chat bubble.
  Future<void> _playBackendAudio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/backend_tts.mp3');
      await file.writeAsBytes(bytes);
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      print('Error playing backend TTS audio: $e');
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;

    // Stop the welcome-banner animation when it's scrolled off screen.
    // This prevents the 60fps CustomPainter from blocking the main thread
    // and causing the keyboard InputConnection crash.
    if (offset > 250) {
      if (_motion.isAnimating) _motion.stop();
    } else {
      if (!_motion.isAnimating && !MediaQuery.disableAnimationsOf(context)) {
        _motion.repeat();
      }
    }

    // Show pinned dock when the big cards are scrolled out of view (approx 380px)
    final shouldShow = offset > 380;
    if (_showPinnedDock != shouldShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _showPinnedDock = shouldShow);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else {
      _motion.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant OrbitChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopListening();
  }

  Future<void> _stopListening({bool cancel = false}) async {
    if (_listening) {
      await _voiceService.stopVoiceChat(cancel: cancel);
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _toggleMic() async {
    if (widget.busy || _starting) return;
    
    // Stop any ongoing AI speech when user taps microphone
    await _audioPlayer.stop();

    if (_listening) {
      await _stopListening();
      setState(() => _voice = false);
      return;
    }
    setState(() {
      _starting = true;
      _voiceError = null;
    });
    try {
      final chatBloc = context.read<ChatBloc>();
      await _voiceService.startVoiceChat(
        chatBloc.sessionId, 
        chatBloc.email, 
        chatBloc.instance
      );
      if (mounted) {
        setState(() {
          _voice = true;
          _listening = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _listening = false;
          _voice = false;
          _voiceError = 'Voice isn’t available: $e. You can still type.';
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (text.isEmpty || widget.busy) return;
    await _stopListening();
    if (!mounted) return;
    setState(() => _voice = false);
    widget.onSend(text);
    _draft.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _voiceService.dispose();
    _motion.dispose();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _blue,
        surface: Colors.white,
      ),
    );
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: LayoutBuilder(
                  builder: (context, available) {
                    final compact = MediaQuery.sizeOf(context).height < 570;
                    final inConversation = widget.messages.isNotEmpty;
                    return Column(
                      children: [
                        if (widget.appHeader != null)
                          widget.appHeader!
                        else
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(
                              'assets/app_logo.png',
                              height: 26,
                            ),
                          ),
                        _toolbar(),
                        _showPinnedDock || compact 
                            ? _shortcutDock(compact)
                            : const SizedBox.shrink(),
                        Expanded(
                          child: Stack(
                            children: [
                              _conversation(!compact),
                              if (_voice)
                                _AiVoiceOverlay(
                                  motion: _motion,
                                  listening: _listening,
                                  onCancel: () {
                                    _stopListening(cancel: true);
                                    setState(() => _voice = false);
                                  },
                                  onDone: () {
                                    _stopListening(cancel: false);
                                    setState(() => _voice = false);
                                  },
                                ),
                            ],
                          ),
                        ),


                        if (widget.error != null)
                          _notice(widget.error!, retry: true),
                        if (_voiceError != null) _notice(_voiceError!),
                        _composer(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 3, 10, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: widget.onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, size: 20, color: _blue),
        ),
        const Expanded(
          child: Text(
            'AI assistant',
            style: TextStyle(
              fontSize: 17,
              letterSpacing: -.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
        // Chat/Voice toggle removed as requested
        PopupMenuButton<String>(
          tooltip: 'Chat options',
          icon: const Icon(Icons.more_vert_rounded, color: _muted, size: 20),
          onSelected: (value) {
            if (value == 'settings') {
              widget.onSettings();
            } else {
              widget.onClear();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'settings', child: Text('AI settings')),
            PopupMenuItem(
              value: 'clear',
              enabled: !widget.busy && widget.messages.isNotEmpty,
              child: const Text('New conversation'),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _openShortcut(ChatShortcut shortcut) async {
    FocusScope.of(context).unfocus();
    await _stopListening();
    if (mounted) widget.onSend(shortcut.label);
  }

  Widget _shortcutDock(bool compact) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAFC),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE8EFF3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final shortcut in ChatShortcut.values)
          Expanded(
            child: Tooltip(
              message: shortcut.label,
              child: InkWell(
                key: ValueKey(shortcut),
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openShortcut(shortcut),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 2,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: shortcut.tint,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          shortcut.icon,
                          color: shortcut.color,
                          size: 22,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 6),
                        Text(
                          shortcut.shortLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _welcomeContent({required bool showActions}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0F8FF), Color(0xFFF1FBF7), Color(0xFFFFFCF5)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'RESOURCEPLUS INTELLIGENCE',
                      style: TextStyle(
                        color: _blue,
                        letterSpacing: 1.4,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: _green,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Less busywork.\nMore possibility.',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 27,
                        height: 1.17,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: SizedBox(
                      width: 88,
                      height: 95,
                      child: AnimatedBuilder(
                        animation: _motion,
                        builder: (_, _) => CustomPaint(
                          painter: _IntelligencePainter(
                            _motion.value,
                            _listening,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Your workday, a little lighter. What can I help with?',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        if (showActions) ...[
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Your work, one tap away',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              Icon(Icons.bolt_rounded, color: Color(0xFFF18A36), size: 20),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Open the details. Pick up right where you left off.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final shortcut in ChatShortcut.values.take(2)) ...[
                if (shortcut != ChatShortcut.attendance)
                  const SizedBox(width: 10),
                Expanded(
                  child: _ShortcutCard(
                    shortcut: shortcut,
                    featured: true,
                    onTap: () => _openShortcut(shortcut),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final shortcut in ChatShortcut.values.skip(2)) ...[
                if (shortcut != ChatShortcut.requests) const SizedBox(width: 8),
                Expanded(
                  child: _ShortcutCard(
                    shortcut: shortcut,
                    featured: false,
                    onTap: () => _openShortcut(shortcut),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (!_voice) ...[
          const SizedBox(height: 18),
          const Text(
            'OR START WITH A LITTLE INSPIRATION',
            style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _prompt(
                Icons.lightbulb_outline_rounded,
                'Find my spark',
                'Help me brainstorm a fresh idea for my next team meeting.',
              ),
              _prompt(
                Icons.wb_sunny_outlined,
                'Shape my day',
                'Help me create a focused plan for my workday.',
              ),
            ],
          ),
        ],
      ],
    );

  Widget _prompt(IconData icon, String title, String prompt) =>
      OutlinedButton.icon(
        onPressed: widget.busy ? null : () => _draft.text = prompt,
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: const BorderSide(color: Color(0xFFE0EAF0)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        icon: Icon(icon, size: 16),
        label: Text(title, style: const TextStyle(fontSize: 11)),
      );

  Widget _conversation(bool showActions) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
    itemCount: widget.messages.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _welcomeContent(showActions: showActions),
        );
      }
      final message = widget.messages[index - 1];
      return Align(
        alignment: message.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: message.isUser
                ? const Color(0xFFEAF4FC)
                : const Color(0xFFF7FAF9),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(message.isUser ? 22 : 6),
              bottomRight: Radius.circular(message.isUser ? 6 : 22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.isUser) ...[
                    const Icon(Icons.auto_awesome, size: 15, color: _green),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      message.isUser ? 'YOU' : 'RESOURCEPLUS AI',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (message.isTyping)
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Thinking…',
                    style: TextStyle(color: _muted),
                  ),
                )
              else
                MarkdownBody(
                  data: message.content,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                ),
              if (!message.isUser && !message.isTyping && message.reasonOptions != null && message.reasonOptions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.reasonOptions!.map((reason) => ActionChip(
                      label: Text(reason, style: const TextStyle(fontSize: 12)),
                      onPressed: () => context.read<ChatBloc>().add(SendMessageEvent(reason)),
                    )).toList(),
                  ),
                ),
              if (!message.isUser && !message.isTyping && message.confirmationId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                        onPressed: () => context.read<ChatBloc>().add(SendMessageEvent('Yes', confirmationId: message.confirmationId)),
                        child: const Text('Confirm'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => context.read<ChatBloc>().add(SendMessageEvent('No', confirmationId: message.confirmationId)),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              if (!message.isUser && !message.isTyping)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Copy response',
                    icon: const Icon(
                      Icons.copy_outlined,
                      size: 16,
                      color: _muted,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Response copied')),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _notice(String text, {bool retry = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF985200), fontSize: 12),
            ),
          ),
        ),
        if (retry)
          TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
      ],
    ),
  );

  Widget _composer() => Container(
    key: const ValueKey('chat_composer'),
    padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFF0F4F6))),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD6E5ED)),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: .06),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: _listening ? 'Stop microphone' : 'Use microphone',
                onPressed: widget.busy || _starting ? null : _toggleMic,
                icon: Icon(
                  _listening
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_rounded,
                  color: _listening ? _green : _blue,
                ),
              ),
              IconButton(
                tooltip: 'Attach details',
                onPressed: widget.busy ? null : () {},
                icon: const Icon(
                  Icons.add_rounded,
                  color: _blue,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _draft,
                  enabled: !widget.busy,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: _ink),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: widget.busy
                        ? 'ResourcePlus AI is thinking…'
                        : _listening
                        ? 'Your words appear here…'
                        : 'Ask about your workday…',
                    hintStyle: const TextStyle(color: _muted, fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _draft,
                builder: (_, value, _) => IconButton.filled(
                  tooltip: 'Send message',
                  style: IconButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE9F1F6),
                    disabledForegroundColor: const Color(0xFF7C9CAF),
                  ),
                  onPressed: value.text.trim().isEmpty || widget.busy
                      ? null
                      : _send,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 21),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Made for your workday.  Always check important details.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 9),
        ),
      ],
    ),
  );
}

extension on ChatShortcut {
  IconData get icon => switch (this) {
    ChatShortcut.attendance => Icons.calendar_month_rounded,
    ChatShortcut.leaveTravel => Icons.flight_takeoff_rounded,
    ChatShortcut.requests => Icons.description_outlined,
    ChatShortcut.notifications => Icons.notifications_none_rounded,
    ChatShortcut.approvals => Icons.verified_user_outlined,
  };
  Color get color => switch (this) {
    ChatShortcut.attendance => const Color(0xFF087A62),
    ChatShortcut.leaveTravel => const Color(0xFF0065A0),
    ChatShortcut.requests => const Color(0xFFB76514),
    ChatShortcut.notifications => const Color(0xFF3769A5),
    ChatShortcut.approvals => const Color(0xFF7758A1),
  };
  Color get tint => switch (this) {
    ChatShortcut.attendance => const Color(0xFFE6F5ED),
    ChatShortcut.leaveTravel => const Color(0xFFE8F3FD),
    ChatShortcut.requests => const Color(0xFFFFF3E5),
    ChatShortcut.notifications => const Color(0xFFECF2FE),
    ChatShortcut.approvals => const Color(0xFFF2EDFA),
  };
  String get shortLabel => switch (this) {
    ChatShortcut.leaveTravel => 'Leave & travel',
    ChatShortcut.approvals => 'Approvals',
    _ => label,
  };
  String get subtitle => this == ChatShortcut.attendance
      ? 'Your time, at a glance'
      : 'Make room for life';
}

class _ShortcutCard extends StatefulWidget {
  const _ShortcutCard({
    required this.shortcut,
    required this.featured,
    required this.onTap,
  });
  final ChatShortcut shortcut;
  final bool featured;
  final VoidCallback onTap;
  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.shortcut;
    return AnimatedScale(
      scale: _pressed ? .96 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      child: Material(
        color: s.tint,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(s),
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          splashColor: s.color.withValues(alpha: .1),
          child: Stack(
            children: [
              if (widget.featured)
                Positioned(
                  top: -12,
                  right: -14,
                  child: Transform.rotate(
                    angle: -.2,
                    child: Icon(
                      s.icon,
                      size: 104,
                      color: s.color.withValues(alpha: .07),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(widget.featured ? 15 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(s.icon, color: s.color, size: 23),
                        ),
                        if (widget.featured) ...[
                          const Spacer(),
                          Icon(
                            Icons.north_east_rounded,
                            color: s.color,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: widget.featured ? 14 : 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: widget.featured ? 0 : 28,
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: s.color,
                          fontSize: widget.featured ? 14 : 11,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (widget.featured) ...[
                      const SizedBox(height: 5),
                      Text(
                        s.subtitle,
                        style: TextStyle(color: s.color, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntelligencePainter extends CustomPainter {
  const _IntelligencePainter(this.phase, this.listening);
  final double phase;
  final bool listening;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .40;

    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(.35),
          const Color(0xFF7B2FBE).withOpacity(.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 1.8));
    canvas.drawCircle(Offset.zero, radius * 1.8, glowPaint);

    // Breathing inner circle
    final innerScale = listening ? (0.55 + 0.12 * math.sin(phase * math.pi * 4)) : 0.55;
    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.5),
          const Color(0xFF7B2FBE).withOpacity(0.3),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * innerScale));
    canvas.drawCircle(Offset.zero, radius * innerScale, innerPaint);

    // Animated orbital rings
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < 14; i++) {
      final t = i / 14;
      final rawOpacity = listening ? (0.3 + 0.4 * math.sin(phase * math.pi * 2 + t * math.pi)) : 0.4;
      final ringOpacity = rawOpacity.clamp(0.0, 1.0);
      strokePaint.shader = LinearGradient(
        colors: [
          Color.lerp(const Color(0xFF00E5FF), const Color(0xFF7B2FBE), t)!.withOpacity(ringOpacity),
          Color.lerp(const Color(0xFF7B2FBE), const Color(0xFF00E5FF), t)!.withOpacity((ringOpacity * 0.3).clamp(0.0, 1.0)),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
      canvas.save();
      canvas.rotate(i * math.pi / 14 + phase * math.pi * 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: radius * (0.4 + 0.25 * math.sin(phase * math.pi * 2 + t * math.pi * 3)),
        ),
        strokePaint,
      );
      canvas.restore();
    }

    // Active indicator dot
    if (listening) {
      final dotPulse = 0.6 + 0.4 * math.sin(phase * math.pi * 6);
      canvas.drawCircle(
        Offset(radius * 0.85, -radius * 0.6),
        5 * dotPulse,
        Paint()..color = const Color(0xFF00E5FF),
      );
    }
  }

  @override
  bool shouldRepaint(_IntelligencePainter old) =>
      phase != old.phase || listening != old.listening;
}

// ─── Futuristic AI Voice Overlay ─────────────────────────────────────────────
class _AiVoiceOverlay extends StatefulWidget {
  const _AiVoiceOverlay({
    required this.motion,
    required this.listening,
    required this.onCancel,
    required this.onDone,
  });
  final Animation<double> motion;
  final bool listening;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_AiVoiceOverlay> createState() => _AiVoiceOverlayState();
}

class _AiVoiceOverlayState extends State<_AiVoiceOverlay>
    with TickerProviderStateMixin {
  late final List<AnimationController> _bars;
  static const _barCount = 9;
  static const _barColors = [
    Color(0xFF00E5FF),
    Color(0xFF29B6F6),
    Color(0xFF7B61FF),
    Color(0xFFB47AEA),
    Color(0xFF00E5FF),
    Color(0xFF29B6F6),
    Color(0xFF7B61FF),
    Color(0xFFB47AEA),
    Color(0xFF00E5FF),
  ];

  @override
  void initState() {
    super.initState();
    _bars = List.generate(_barCount, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 380 + i * 60),
        lowerBound: 0.12,
        upperBound: 1.0,
      )..repeat(reverse: true);
      // stagger
      Future.delayed(Duration(milliseconds: i * 45), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _bars) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.95), // Clean white background
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // Title
              Text(
                widget.listening ? 'Listening...' : 'Processing...',
                style: const TextStyle(
                  color: Color(0xFF1E293B), // Dark text for contrast
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.listening 
                  ? 'Speak clearly into your microphone' 
                  : 'Preparing AI Assistant...',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 80),

              // Simple Pulsing Microphone - Tap to send
              AnimatedBuilder(
                animation: widget.motion,
                builder: (_, child) {
                  final scale = widget.listening ? (1.0 + 0.15 * math.sin(widget.motion.value * math.pi * 4)) : 1.0;
                  return GestureDetector(
                    onTap: widget.onDone, // Tapping mic finishes recording
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF), // Light blue circle
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (widget.listening)
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                blurRadius: 30 * scale,
                                spreadRadius: 10 * scale,
                              ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          size: 60,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              TextButton(
                onPressed: widget.onDone,
                child: const Text('Tap microphone to finish', style: TextStyle(color: Color(0xFF94A3B8))),
              ),

              const SizedBox(height: 30),

              // Cancel button
              InkWell(
                onTap: widget.onCancel,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

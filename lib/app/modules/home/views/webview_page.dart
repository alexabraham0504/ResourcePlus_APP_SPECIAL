import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_storage/get_storage.dart';
import '../../../widgets/error_page_widget.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({Key? key, required this.url, required this.title})
      : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? webViewController;
  bool isLoading = true;
  double loadingProgress = 0.0;
  String? errorMessage;
  bool _hasShownPermissionDialog = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF1E3A8A);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController!.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
            if (errorMessage != null)
              _buildFuturisticError()
            else
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: """
                      // Shim for missing functions in legacy scripts
                      if (typeof window.Populatemenu === 'undefined') {
                        window.Populatemenu = function() {
                          console.log('Populatemenu shim called');
                        };
                      }
                    """,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(

                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsBackForwardNavigationGestures: true,
                  allowsLinkPreview: true,
                  geolocationEnabled: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  hardwareAcceleration: true,
                  safeBrowsingEnabled: false,
                  thirdPartyCookiesEnabled: true,
                  userAgent:
                      "Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
                  cacheEnabled: true, // Keep cache enabled so session cookies persist
                  cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK, // Prefer cached content for speed
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  textZoom: 100,
                  networkAvailable: true,
                  allowFileAccess: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  useOnRenderProcessGone: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  allowsInlineMediaPlayback: true,
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  if (mounted) {
                    setState(() {
                      isLoading = true;
                      loadingProgress = 0.0;
                    });
                  }
                },
                onProgressChanged: (controller, progress) {
                  if (mounted) {
                    setState(() {
                      loadingProgress = progress.toDouble();
                    });
                  }
                },
                onLoadStop: (controller, url) async {
                  if (mounted) {
                    setState(() {
                      isLoading = false;
                    });
                  }

                  _injectNavigationPreventionScript();
                  await _injectAutoLoginScript();
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('WebView Resource Error: ${error.description} (Code: ${error.type}) for URL: ${request.url}');
                  // Don't show error page for minor SSL subresource issues
                  if (error.type == WebResourceErrorType.CANCELLED || 
                      error.type == WebResourceErrorType.TIMEOUT) return;

                  if (request.isForMainFrame == true && mounted) {
                    setState(() {
                      errorMessage = 'Failed to load page: ${error.description}';
                      isLoading = false;
                    });
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  debugPrint('WebView HTTP Error: ${errorResponse.statusCode} for URL: ${request.url}');
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  return ServerTrustAuthResponse(
                    action: ServerTrustAuthResponseAction.PROCEED,
                  );
                },

                onRenderProcessGone: (controller, detail) async {
                  // Handle WebView renderer crashes gracefully
                  if (mounted) {
                    setState(() {
                      errorMessage = 'WebView crashed. Reloading...';
                      isLoading = true;
                    });

                    // Wait a moment then reload
                    await Future.delayed(const Duration(seconds: 3));
                    await controller.reload();

                    setState(() {
                      errorMessage = null;
                      isLoading = false;
                    });
                  }
                },
                onPermissionRequest: (controller, request) async {
                  // Grant ALL permissions including camera
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onConsoleMessage: (controller, consoleMessage) {
                  // Silent console messages
                },
                onJsAlert: (controller, jsAlertRequest) async {
                  return JsAlertResponse(handledByClient: true);
                },
                onJsConfirm: (controller, jsConfirmRequest) async {
                  return JsConfirmResponse(
                    handledByClient: true,
                    action: JsConfirmResponseAction.CONFIRM,
                  );
                },
              ),
            if (isLoading)
              _buildLoadingOverlay(),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildFuturisticError() {
    // Detect error type from message
    final msg = (errorMessage ?? '').toLowerCase();
    ErrorType errorType;
    if (msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('host lookup') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('no address') ||
        msg.contains('dns')) {
      errorType = ErrorType.connection;
    } else if (msg.contains('500') ||
        msg.contains('503') ||
        msg.contains('server')) {
      errorType = ErrorType.server;
    } else {
      errorType = ErrorType.unknown;
    }

    return FuturisticErrorPage(
      onRetry: () {
        setState(() {
          errorMessage = null;
          isLoading = true;
          loadingProgress = 0.0;
        });
        webViewController?.reload();
      },
      errorType: errorType,
    );
  }

  Widget _buildLoadingOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // Gradient progress bar at top
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: loadingProgress),
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value > 0 ? value / 100 : null,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF3B82F6),
                ),
                minHeight: 3,
              );
            },
          ),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _injectAutoLoginScript() async {
    try {
      final storage = GetStorage();
      final username = storage.read('username') ?? '';
      final password = storage.read('password') ?? '';

      if (username.isNotEmpty && password.isNotEmpty) {
        await webViewController?.evaluateJavascript(source: '''
          (function() {
            var userField = document.getElementById('txtUserName') || document.querySelector('input[type="text"]');
            var passField = document.getElementById('txtPassword') || document.querySelector('input[type="password"]');
            
            if (userField && passField) {
              if (userField.value === '' || passField.value === '') {
                userField.value = '$username';
                passField.value = '$password';
                
                // Attempt to auto-login to bypass the login screen when session expires
                setTimeout(function() {
                  var loginBtn = document.getElementById('btnLogin') || 
                                 document.getElementById('btnSubmit') || 
                                 document.querySelector('input[type="submit"]') || 
                                 document.querySelector('button[type="submit"]') ||
                                 document.querySelector('.login-btn');
                                 
                  var captchaField = document.getElementById('txtCaptcha') || document.getElementById('captcha');
                  
                  // Only auto-click if we don't detect a captcha field that needs manual entry
                  if (loginBtn && !captchaField) {
                    loginBtn.click();
                  } else if (loginBtn) {
                     // Try clicking anyway, some captchas are v3 invisible
                     loginBtn.click();
                  }
                }, 500);
              }
            }
          })();
        ''');
      }
    } catch (e) {
      debugPrint('Auto-login script injection failed: $e');
    }
  }

  Future<void> _injectNavigationPreventionScript() async {
    try {
      await webViewController?.evaluateJavascript(
        source: '''
        // Enhanced camera support with stability improvements
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
          
          navigator.mediaDevices.getUserMedia = function(constraints) {
            console.log('Camera access requested with constraints:', constraints);
            
            // Add timeout to prevent hanging
            const timeoutPromise = new Promise((_, reject) => {
              setTimeout(() => reject(new Error('Camera access timeout after 15 seconds')), 15000);
            });
            
            const cameraPromise = originalGetUserMedia(constraints);
            
            return Promise.race([cameraPromise, timeoutPromise])
              .then(function(stream) {
                console.log('Camera access successful');
                return stream;
              })
              .catch(function(error) {
                console.error('Camera access failed:', error);
                // Show helpful error message
                alert('Camera access failed: ' + error.message + '\\n\\nPlease ensure camera permissions are granted and try again.');
                throw error;
              });
          };
        }
        
        // Prevent navigation back during camera operations
        let isCameraActive = false;
        
        const originalBack = history.back;
        history.back = function() {
          if (isCameraActive) {
            console.log('Back navigation blocked during camera operation');
            return;
          }
          originalBack.call(history);
        };
        
        const originalGo = history.go;
        history.go = function(delta) {
          if (isCameraActive && delta < 0) {
            console.log('Back navigation blocked during camera operation');
            return;
          }
          originalGo.call(history, delta);
        };
        
        // Monitor camera state
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
          
          navigator.mediaDevices.getUserMedia = function(constraints) {
            isCameraActive = true;
            console.log('Camera operation started');
            
            return originalGetUserMedia(constraints)
              .then(function(stream) {
                isCameraActive = false;
                console.log('Camera operation completed successfully');
                return stream;
              })
              .catch(function(error) {
                isCameraActive = false;
                console.log('Camera operation failed');
                throw error;
              });
          };
        }
        
        console.log('Enhanced camera support script loaded');
      ''',
      );
    } catch (e) {
      // Silent fail
    }
  }

}

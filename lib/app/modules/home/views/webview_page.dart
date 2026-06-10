import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_storage/get_storage.dart';

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
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          errorMessage = null;
                          isLoading = true;
                        });
                        // Reloading handled by WebView creation or refresh logic
                        webViewController?.reload();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
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
              Container(
                color: Colors.white,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        ),
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

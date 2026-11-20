import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('google.accounts.id')
external JSGoogleIdentity? get _googleIdentity;

extension type JSGoogleIdentity._(JSObject _) implements JSObject {
  external void initialize(JSObject configuration);
  external void prompt();
}

extension type JSGoogleCredentialResponse._(JSObject _) implements JSObject {
  external JSString? get credential;
}

class GoogleOneTapPlatform extends StatefulWidget {
  const GoogleOneTapPlatform({
    super.key,
    required this.clientId,
    required this.onCredential,
  });

  final String clientId;
  final ValueChanged<String> onCredential;

  @override
  State<GoogleOneTapPlatform> createState() => _GoogleOneTapPlatformState();
}

class _GoogleOneTapPlatformState extends State<GoogleOneTapPlatform> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant GoogleOneTapPlatform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) unawaited(_start());
  }

  Future<void> _start() async {
    if (_started || widget.clientId.trim().isEmpty) return;
    _started = true;
    await _ensureGoogleScript();
    if (!mounted) return;
    final identity = _googleIdentity;
    if (identity == null) return;
    identity.initialize(
      {
            'client_id': widget.clientId,
            // Do not auto-select an account: users must always see a Google-owned
            // account choice/consent surface before Kaydo creates a session.
            'auto_select': false,
            'cancel_on_tap_outside': true,
            'context': 'signin',
            'itp_support': true,
            'callback': (JSGoogleCredentialResponse response) {
              final credential = response.credential?.toDart;
              if (credential != null && credential.isNotEmpty) {
                widget.onCredential(credential);
              }
            }.toJS,
          }.jsify()!
          as JSObject,
    );
    identity.prompt();
  }

  Future<void> _ensureGoogleScript() async {
    const selector = 'script[data-kaydo-google-identity="1"]';
    if (web.document.querySelector(selector) == null) {
      final script = web.HTMLScriptElement()
        ..src = 'https://accounts.google.com/gsi/client'
        ..async = true
        ..defer = true
        ..dataset['kaydoGoogleIdentity'] = '1';
      final loaded = Completer<void>();
      script.onload = (web.Event _) {
        if (!loaded.isCompleted) loaded.complete();
      }.toJS;
      script.onerror = (web.Event _) {
        if (!loaded.isCompleted) loaded.complete();
      }.toJS;
      web.document.head?.append(script);
      await loaded.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
    }
    for (var attempt = 0; attempt < 30 && _googleIdentity == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

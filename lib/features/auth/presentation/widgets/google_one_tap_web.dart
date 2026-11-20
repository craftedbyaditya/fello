import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'google_one_tap_credential.dart';

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
  final ValueChanged<GoogleOneTapCredential> onCredential;

  @override
  State<GoogleOneTapPlatform> createState() => _GoogleOneTapPlatformState();
}

class _GoogleOneTapPlatformState extends State<GoogleOneTapPlatform> {
  bool _started = false;
  late String _rawNonce;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant GoogleOneTapPlatform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) {
      _started = false;
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    if (_started || widget.clientId.trim().isEmpty) return;
    _started = true;
    _rawNonce = _generateRawNonce();
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
            // Supabase validates this against the `nonce` claim in the Google
            // ID token. Google receives the SHA-256 digest; Supabase receives
            // the original value when the credential is exchanged.
            'nonce': sha256.convert(utf8.encode(_rawNonce)).toString(),
            'callback': (JSGoogleCredentialResponse response) {
              final credential = response.credential?.toDart;
              if (credential != null && credential.isNotEmpty) {
                widget.onCredential(
                  GoogleOneTapCredential(idToken: credential, nonce: _rawNonce),
                );
              }
            }.toJS,
          }.jsify()!
          as JSObject,
    );
    identity.prompt();
  }

  String _generateRawNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
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

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/theme/fello_colors.dart';

@JS('turnstile')
external JSTurnstile? get _turnstile;

extension type JSTurnstile._(JSObject _) implements JSObject {
  external int render(web.HTMLElement element, JSObject params);
}

class TurnstilePlatformView extends StatefulWidget {
  const TurnstilePlatformView({
    super.key,
    required this.siteKey,
    required this.onToken,
  });

  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  State<TurnstilePlatformView> createState() => _TurnstilePlatformViewState();
}

class _TurnstilePlatformViewState extends State<TurnstilePlatformView> {
  late final String _viewType =
      'kaydo-turnstile-${DateTime.now().microsecondsSinceEpoch}';
  bool _ready = false;
  web.HTMLDivElement? _host;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final host = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.minHeight = '65px';
      _host = host;
      return host;
    });
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await _ensureScript();
    if (!mounted) return;
    setState(() => _ready = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _render();
  }

  Future<void> _ensureScript() async {
    if (web.document.querySelector('script[data-kaydo-cf="1"]') != null) {
      for (var i = 0; i < 30 && _turnstile == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    final script = web.HTMLScriptElement()
      ..src =
          'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
      ..async = true
      ..dataset['kaydoCf'] = '1';
    final done = Completer<void>();
    script.onload = (web.Event _) {
      if (!done.isCompleted) done.complete();
    }.toJS;
    web.document.head!.append(script);
    await done.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {},
    );
    for (var i = 0; i < 30 && _turnstile == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _render() {
    final host = _host;
    final api = _turnstile;
    if (host == null || api == null) return;
    try {
      final params = {
        'sitekey': widget.siteKey,
        'callback': (JSString token) {
          widget.onToken(token.toDart);
        }.toJS,
        'expired-callback': () {
          widget.onToken(null);
        }.toJS,
        'error-callback': () {
          widget.onToken(null);
        }.toJS,
      }.jsify()!;
      api.render(host, params as JSObject);
    } catch (_) {
      widget.onToken(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox(
        height: 65,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: FelloColors.accent,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 70,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

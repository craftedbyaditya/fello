import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

const _storageKey = 'kaydo_submit_client_key';

String readStoredClientKey() {
  return web.window.localStorage.getItem(_storageKey) ?? '';
}

void writeStoredClientKey(String value) {
  web.window.localStorage.setItem(_storageKey, value);
}

String createClientKey() => const Uuid().v4();

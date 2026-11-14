import 'package:uuid/uuid.dart';

String readStoredClientKey() => '';

void writeStoredClientKey(String value) {}

String createClientKey() => const Uuid().v4();

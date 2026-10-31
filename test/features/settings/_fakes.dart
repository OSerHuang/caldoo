import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:caldoo/features/settings/ai_settings.dart';

/// Deliberately NOT key-shaped (`sk-...`): the plan's scoped secret scan
/// (`grep -rnE '(^|[^a-zA-Z])sk-[A-Za-z0-9_-]{16,}' lib/ android/ test/`)
/// runs over `test/` too, so fixtures must use a non-key placeholder.
const String testApiKey = 'test-key-settings-0123456789abcdef';

/// In-memory [SecureKeyStore] fake: stands in for `flutter_secure_storage`
/// in tests and lets assertions inspect exactly what was persisted.
class InMemorySecureKeyStore implements SecureKeyStore {
  String? value;
  int writeCount = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    writeCount++;
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

/// Serves canned [ResponseBody]s; no socket is ever opened.
class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  int calls = 0;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio instance wired to [MockAdapter].
({Dio dio, MockAdapter adapter}) mockDio(
  ResponseBody Function(RequestOptions options) respond,
) {
  final Dio dio = Dio();
  final MockAdapter adapter = MockAdapter(respond);
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

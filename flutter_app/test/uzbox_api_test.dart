import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uzbox_flutter/api/uzbox_api.dart';

void main() {
  test('default API clients share the in-memory login session', () {
    final first = UzBoxApi();
    final second = UzBoxApi();
    first.accessToken = 'test-session-token';

    expect(identical(first, second), isTrue);
    expect(second.accessToken, 'test-session-token');

    first.clearSession();
    expect(second.accessToken, isNull);
  });

  test('decodes the backend-recommended PSU wattage', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/compat/check');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body['components'], {'cpu': 'r7-9800x3d', 'gpu': 'rtx-5070'});
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'recommended_psu_watt': 750}));
      await request.response.close();
    });

    final api = UzBoxApi(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    expect(
      await api.recommendedPsuWatt(cpuId: 'r7-9800x3d', gpuId: 'rtx-5070'),
      750,
    );
  });
}

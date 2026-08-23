import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class UzBoxApiException implements Exception {
  const UzBoxApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// The account returned by the authentication endpoints.
///
/// Authentication data is intentionally kept as plain value objects.  The
/// API client keeps the bearer token in memory only; callers that want a
/// longer-lived session must provide their own platform-secure storage.
class UzBoxAccount {
  const UzBoxAccount({
    required this.id,
    required this.phone,
    required this.nickname,
  });

  final String id;
  final String? phone;
  final String? nickname;

  factory UzBoxAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const UzBoxApiException('登录响应缺少账号信息');
    }
    return UzBoxAccount(
      id: id,
      phone: json['phone']?.toString(),
      nickname: json['nickname']?.toString(),
    );
  }
}

class UzBoxSmsResult {
  const UzBoxSmsResult({required this.sent, this.debugCode});

  final bool sent;

  /// Only present when the backend is explicitly running in debug SMS mode.
  /// Production providers must never return a code here.
  final String? debugCode;

  factory UzBoxSmsResult.fromJson(Map<String, dynamic> json) {
    return UzBoxSmsResult(
      sent: json['sent'] == true,
      debugCode: json['debug_code']?.toString(),
    );
  }
}

class UzBoxAuthSession {
  const UzBoxAuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.account,
  });

  final String accessToken;
  final String tokenType;
  final UzBoxAccount account;

  factory UzBoxAuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw const UzBoxApiException('登录响应缺少访问令牌');
    }
    final accountJson = json['account'];
    if (accountJson is! Map) {
      throw const UzBoxApiException('登录响应缺少账号信息');
    }
    return UzBoxAuthSession(
      accessToken: token,
      tokenType: json['token_type']?.toString() ?? 'bearer',
      account: UzBoxAccount.fromJson(Map<String, dynamic>.from(accountJson)),
    );
  }
}

abstract interface class UzBoxAuthClient {
  String? get accessToken;

  Future<UzBoxSmsResult> sendSmsCode(String phone);

  Future<UzBoxAuthSession> loginWithSmsCode({
    required String phone,
    required String code,
  });

  Future<UzBoxAccount> currentAccount();

  void clearSession();
}

class UzBoxApi implements UzBoxAuthClient {
  UzBoxApi._({Uri? baseUri, HttpClient? client, this._accessToken})
    : baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'UZBOX_API_BASE_URL',
              defaultValue: 'https://api.uzbox.top',
            ),
          ),
      _client = client ?? HttpClient();

  /// The app uses one in-memory client by default so the bearer token obtained
  /// at login is also attached to API clients created by feature screens.
  /// Supplying a base URI, HTTP client, or token creates an isolated client for
  /// tests and specialised integrations.
  factory UzBoxApi({Uri? baseUri, HttpClient? client, String? accessToken}) {
    if (baseUri == null && client == null && accessToken == null) {
      return _shared;
    }
    return UzBoxApi._(
      baseUri: baseUri,
      client: client,
      accessToken: accessToken,
    );
  }

  static final UzBoxApi _shared = UzBoxApi._();

  final Uri baseUri;
  final HttpClient _client;
  String? _accessToken;

  /// The current bearer token, kept in memory only.
  @override
  String? get accessToken => _accessToken;

  /// Replace the in-memory session token.  Do not persist this value in a
  /// regular preference; use Keychain/Android Keystore if persistence is
  /// required by the host app.
  set accessToken(String? value) => _accessToken = value;

  @override
  void clearSession() => _accessToken = null;

  @override
  Future<UzBoxSmsResult> sendSmsCode(String phone) async {
    final value = await _mapRequest(
      'POST',
      '/v1/auth/sms/send',
      body: {'phone': phone},
    );
    return UzBoxSmsResult.fromJson(value);
  }

  @override
  Future<UzBoxAuthSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    final value = await _mapRequest(
      'POST',
      '/v1/auth/login',
      body: {'phone': phone, 'code': code},
    );
    final session = UzBoxAuthSession.fromJson(value);
    _accessToken = session.accessToken;
    return session;
  }

  @override
  Future<UzBoxAccount> currentAccount() async {
    final value = await _mapRequest('GET', '/v1/auth/me');
    return UzBoxAccount.fromJson(value);
  }

  Future<Map<String, dynamic>> health() => _mapRequest('GET', '/health');

  Future<Map<String, dynamic>> catalogReadiness() =>
      _mapRequest('GET', '/v1/catalog/readiness');

  Future<List<Map<String, dynamic>>> catalogComponents({
    required String category,
    int limit = 100,
  }) => _listRequest(
    'GET',
    '/v1/catalog/components',
    query: {'category': category, 'limit': '$limit'},
  );

  Future<List<Map<String, dynamic>>> catalogPrices({int limit = 500}) =>
      _listRequest('GET', '/v1/catalog/prices', query: {'limit': '$limit'});

  Future<int?> recommendedPsuWatt({
    required String cpuId,
    required String gpuId,
  }) async {
    final response = await _mapRequest(
      'POST',
      '/v1/compat/check',
      body: {
        'components': {'cpu': cpuId, 'gpu': gpuId},
      },
    );
    final watt = response['recommended_psu_watt'];
    return watt is num ? watt.round() : null;
  }

  Future<Map<String, dynamic>> buildOptions({
    required int budget,
    required String useCase,
    required List<String> gameCategories,
    required String direction,
    List<String> officeApps = const [],
    bool needsWirelessNetwork = false,
    String memorySize = '16GB',
    String storageSize = '512GB',
    bool noGpuBuild = false,
    String? ownedGpuModel,
  }) => _mapRequest(
    'POST',
    '/v1/build/options',
    body: {
      'budget': budget,
      'use_case': useCase,
      'game_categories': gameCategories,
      'direction': direction,
      'office_apps': officeApps,
      'needs_wireless_network': needsWirelessNetwork,
      'memory_size': memorySize,
      'storage_size': storageSize,
      'no_gpu_build': noGpuBuild,
      'owned_gpu_model': ownedGpuModel,
    },
  );

  Future<Map<String, dynamic>> reviewText(String text) =>
      _mapRequest('POST', '/v1/review/analyze', body: {'text': text});

  Future<Map<String, dynamic>> reviewImage(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final uri = baseUri.resolve('/v1/review/analyze/image');
    final boundary = 'UzBox-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final request = await _client
          .postUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="image"; filename="config.jpg"\r\n',
      );
      request.write('Content-Type: $contentType\r\n\r\n');
      request.add(bytes);
      request.write('\r\n--$boundary--\r\n');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final text = await utf8.decoder.bind(response).join();
      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']?.toString()
            : null;
        throw UzBoxApiException(
          detail ?? '图片分析失败（${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const UzBoxApiException('服务器返回了无法识别的数据');
      }
      return decoded;
    } on UzBoxApiException {
      rethrow;
    } on TimeoutException {
      throw const UzBoxApiException('图片分析超时，请稍后重试');
    } on SocketException {
      throw const UzBoxApiException('无法连接服务器，请检查网络');
    }
  }

  Future<Map<String, dynamic>> estimatePerformance({
    required String cpuId,
    required String gpuId,
    required String resolution,
    required List<String> gameIds,
  }) => _mapRequest(
    'POST',
    '/v1/perf/estimate',
    body: {
      'hardware': {'cpu': cpuId, 'gpu': gpuId},
      'resolution': resolution,
      'games': gameIds,
    },
  );

  Future<Map<String, dynamic>> upgradePlan({
    required int budget,
    required Map<String, dynamic> current,
    required String need,
    required List<String> games,
    required String resolution,
    required int targetFps,
  }) => _mapRequest(
    'POST',
    '/v1/upgrade/plan',
    body: {
      'budget': budget,
      'current': current,
      'need': need,
      'games': games,
      'resolution': resolution,
      'target_fps': targetFps,
    },
  );

  Future<Map<String, dynamic>> _mapRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final value = await _request(method, path, query: query, body: body);
    if (value is! Map<String, dynamic>) {
      throw const UzBoxApiException('服务器返回了无法识别的数据');
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> _listRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final value = await _request(method, path, query: query, body: body);
    if (value is! List) {
      throw const UzBoxApiException('服务器返回了无法识别的数据');
    }
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = baseUri.resolve(path).replace(queryParameters: query);
    try {
      final request = await _client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      final accessToken = _accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await utf8.decoder.bind(response).join();
      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']?.toString()
            : null;
        throw UzBoxApiException(
          detail ?? '请求失败（${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on UzBoxApiException {
      rethrow;
    } on TimeoutException {
      throw const UzBoxApiException('连接服务器超时，请稍后重试');
    } on SocketException {
      throw const UzBoxApiException('无法连接服务器，请检查网络');
    } on FormatException {
      throw const UzBoxApiException('服务器返回了无法识别的数据');
    }
  }
}

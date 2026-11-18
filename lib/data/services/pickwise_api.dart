import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class PickwiseApi {
  PickwiseApi({http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl = _resolveBaseUrl(baseUrl);
  static String _resolveBaseUrl(String? explicit) {
    final value = explicit ?? defaultBaseUrl;
    if (kReleaseMode) validateDeploymentUrl(value);
    return value;
  }

  static String get defaultBaseUrl {
    const override = String.fromEnvironment('PICKWISE_API_URL');
    if (override.isNotEmpty) {
      if (kReleaseMode) validateDeploymentUrl(override);
      return override;
    }
    if (kReleaseMode) {
      throw StateError('릴리스 빌드에는 HTTPS PICKWISE_API_URL 설정이 필요합니다.');
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }

  static void validateDeploymentUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2') {
      throw ArgumentError('공개 HTTPS API 주소를 사용해주세요.');
    }
  }

  Future<bool> Function()? refreshSession;
  VoidCallback? sessionExpired;
  int sessionEpoch = 0;
  final http.Client client;
  final String baseUrl;
  String? token;
  bool get configured => baseUrl.isNotEmpty;

  Future<dynamic> request(String method, String path, [Object? body]) =>
      _request(method, path, body, true);
  Future<dynamic> _request(
    String method,
    String path,
    Object? body,
    bool retry,
  ) async {
    final epoch = sessionEpoch;
    final sentToken = token;
    if (!configured) throw const ApiException(0, '서버 주소를 설정해주세요.');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 10)),
    ).timeout(const Duration(seconds: 10));
    if (epoch != sessionEpoch &&
        (path.contains('/me/') ||
            path.startsWith('/api/v1/admin/') ||
            path == '/api/v1/auth/me' ||
            path == '/api/v1/auth/logout')) {
      throw const ApiException(401, '계정이 변경됐어요.');
    }
    if (response.statusCode == 401 &&
        ![
          '/api/v1/auth/login',
          '/api/v1/auth/register',
          '/api/v1/auth/refresh',
        ].contains(path)) {
      final refreshed = retry && refreshSession != null
          ? (sentToken != token && token != null || await refreshSession!())
          : false;
      if (epoch != sessionEpoch) throw const ApiException(401, '계정이 변경됐어요.');
      if (refreshed && method == 'GET') {
        return _request(method, path, body, false);
      }
      if (!refreshed && epoch == sessionEpoch) {
        token = null;
        sessionExpired?.call();
      }
      if (refreshed) {
        throw const ApiException(401, '로그인을 갱신했어요. 저장 여부를 확인한 뒤 다시 시도해주세요.');
      }
    }
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, switch (response.statusCode) {
        401 => '로그인 정보가 올바르지 않거나 만료됐어요. 다시 로그인해주세요.',
        403 => '관리자 권한이 없어요. 계정 권한을 확인해주세요.',
        409 => '중복 계정이거나 다른 곳에서 수정한 기록이에요. 새로고침해주세요.',
        404 => '정보를 찾을 수 없어요.',
        400 => '입력한 정보를 확인해주세요.',
        422 => '현재 비밀번호를 확인해주세요.',
        429 => '요청이 많아요. 잠시 후 다시 시도해주세요.',
        _ => '서버 요청에 실패했어요. 잠시 후 다시 시도해주세요.',
      });
    }
    return response.statusCode == 204
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }
}

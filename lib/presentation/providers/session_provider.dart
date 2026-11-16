import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/services/pickwise_api.dart';
import '../../data/models/product_preferences.dart';
import 'product_provider.dart';

abstract class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  final _storage = const FlutterSecureStorage();
  static const _key = 'pickwise.session.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required this.api,
    required this.products,
    SessionStorage? storage,
  }) : storage = storage ?? SecureSessionStorage() {
    api.refreshSession = refresh;
    api.sessionExpired = () => unawaited(
      clear().catchError((Object _) {
        message = '보안 저장소 정리에 실패했어요. 앱을 다시 실행해주세요.';
        notifyListeners();
      }),
    );
  }
  final PickwiseApi api;
  final ProductProvider products;
  final SessionStorage storage;
  String? email, userId, _refreshToken;
  String? message;
  bool restoring = false;
  Map<String, dynamic> _sessionData = {};
  bool _preserveGuestDraft = false;
  Future<bool>? _refreshing;
  int? _refreshGeneration;
  Future<void> _storageQueue = Future.value();
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> _serialize(Future<void> Function() work) {
    final result = _storageQueue.then((_) => work());
    // 호출자는 result로 오류를 받고, 대기열은 다음 정리 작업을 계속 처리한다.
    _storageQueue = result.catchError((Object _) {});
    return result;
  }

  int get generation => api.sessionEpoch;
  bool get loggedIn => userId != null;
  Future<void> initialize() async {
    final epoch = generation;
    message = null;
    restoring = true;
    notifyListeners();
    try {
      final raw = await storage.read();
      if (raw != null && epoch == generation) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final expiry = DateTime.tryParse(
          data['refreshExpiresAt'] as String? ?? '',
        );
        if (expiry == null || !expiry.isAfter(DateTime.now())) {
          await clear();
          return;
        }
        _sessionData = data;
        userId = data['userId'] as String?;
        email = data['email'] as String?;
        if (userId != null) await products.switchIdentity(userId!);
        if (epoch != generation) return;
        api.token = data['accessToken'] as String?;
        _refreshToken = data['refreshToken'] as String?;
        await _identify();
      }
    } catch (e) {
      if (epoch != generation) return;
      if (e is ApiException && e.status == 401) {
        await clear();
      } else {
        message = '서버 연결을 확인해주세요. 저장된 로그인은 연결 후 다시 확인할 수 있어요.';
      }
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(
    String email,
    String password, {
    bool register = false,
  }) async {
    final epoch = generation;
    _preserveGuestDraft = !loggedIn && products.hasEditedPreferences;
    final result = await api.request(
      'POST',
      '/api/v1/auth/${register ? 'register' : 'login'}',
      {'email': email, 'password': password},
    );
    if (epoch != generation) return;
    final loginEpoch = ++api.sessionEpoch;
    _sessionData = {};
    message = null;
    api.token = null;
    userId = null;
    this.email = null;
    await products.switchIdentity('guest');
    await _store(Map<String, dynamic>.from(result as Map), loginEpoch);
    if (loginEpoch != generation) return;
    await _identify();
  }

  Future<void> _store(Map<String, dynamic> data, int epoch) =>
      _serialize(() async {
        if (epoch != generation) return;
        _sessionData = {..._sessionData, ...data};
        await storage.write(jsonEncode(_sessionData));
        if (epoch != generation) return;
        api.token = data['accessToken'] as String;
        _refreshToken = data['refreshToken'] as String;
      });
  Future<void> _identify() async {
    final epoch = generation;
    final me = await api.request('GET', '/api/v1/auth/me');
    if (epoch != generation) return;
    userId = me['id'] as String;
    email = me['email'] as String;
    await products.switchIdentity(userId!, preserveDraft: _preserveGuestDraft);
    _preserveGuestDraft = false;
    if (epoch != generation) return;
    await _serialize(() async {
      if (epoch != generation) return;
      _sessionData = {..._sessionData, 'userId': userId, 'email': email};
      await storage.write(jsonEncode(_sessionData));
    });
    if (epoch != generation) return;
    notifyListeners();
    final revision = products.preferenceRevision;
    try {
      final result = await api.request('GET', '/api/v1/me/preferences');
      if (epoch == generation && revision == products.preferenceRevision) {
        products.applyDefaultPreferences(
          ProductPreferences.fromJson(
            Map<String, dynamic>.from(result['preferences'] as Map),
          ),
        );
      }
    } catch (e) {
      if (epoch == generation) {
        message = '기본 취향을 불러오지 못했어요. 다시 불러올 수 있어요.';
        notifyListeners();
      }
    }
  }

  Future<bool> refresh() {
    final epoch = generation;
    if (_refreshing != null && _refreshGeneration == epoch) return _refreshing!;
    _refreshGeneration = epoch;
    return _refreshing = _doRefresh().whenComplete(() {
      if (_refreshGeneration == epoch) _refreshing = null;
    });
  }

  Future<bool> _doRefresh() async {
    final token = _refreshToken, epoch = generation;
    if (token == null) return false;
    try {
      final data = await api.request('POST', '/api/v1/auth/refresh', {
        'refreshToken': token,
      });
      if (epoch != generation) return false;
      await _store(Map<String, dynamic>.from(data as Map), epoch);
      return epoch == generation;
    } catch (e) {
      if (epoch == generation && e is ApiException && e.status == 401) {
        await clear();
      }
      // A lost rotation response cannot safely be replayed with the old refresh token.
      return false;
    }
  }

  Future<void> saveDefaultPreferences({ProductPreferences? preferences}) async {
    final epoch = generation;
    final value = preferences ?? products.selectionPreferences;
    await api.request('PUT', '/api/v1/me/preferences', value.toJson());
    if (epoch != generation) return;
    products.applyDefaultPreferences(value);
    message = '기본 취향을 저장했어요.';
    notifyListeners();
  }

  Future<void> loadDefaultPreferences({bool applyToSelection = true}) async {
    final epoch = generation, revision = products.preferenceRevision;
    final result = await api.request('GET', '/api/v1/me/preferences');
    if (epoch != generation) return;
    final value = ProductPreferences.fromJson(
      Map<String, dynamic>.from(result['preferences'] as Map),
    );
    products.applyDefaultPreferences(value);
    if (applyToSelection && revision == products.preferenceRevision) {
      products.updateSelectionPreferences(value);
    }
  }

  Future<void> changePassword(String current, String next) async {
    final epoch = generation;
    await api.request('PUT', '/api/v1/me/password', {
      'currentPassword': current,
      'newPassword': next,
    });
    if (epoch != generation) return;
    try {
      await clear();
    } catch (_) {
      throw const ApiException(0, '비밀번호는 변경됐어요. 앱을 다시 열고 새 비밀번호로 로그인해주세요.');
    }
  }

  Future<void> logout() async {
    final epoch = generation;
    try {
      if (!await refresh()) {
        if (loggedIn) {
          throw const ApiException(
            0,
            '서버 연결 실패로 기기에서만 로그아웃했어요. 서버 세션 폐기는 확인되지 않았어요.',
          );
        }
        return;
      }
      await api.request('POST', '/api/v1/auth/logout');
    } finally {
      if (epoch == generation) await clear();
    }
  }

  Future<void> clear() async {
    final epoch = ++api.sessionEpoch;
    api.token = null;
    _refreshToken = null;
    userId = null;
    email = null;
    _sessionData = {};
    message = '로그인이 종료됐어요. 필요하면 다시 로그인해주세요.';
    final clearing = _serialize(() async {
      if (epoch == generation) await storage.clear();
    });
    await products.switchIdentity('guest');
    if (epoch == generation) notifyListeners();
    await clearing;
  }

  @override
  void dispose() {
    _disposed = true;
    api.refreshSession = null;
    api.sessionExpired = null;
    api.client.close();
    super.dispose();
  }
}

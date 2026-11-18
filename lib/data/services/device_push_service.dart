import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pickwise_api.dart';

@pragma('vm:entry-point')
Future<void> pickWiseBackgroundMessage(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

class DevicePushService {
  DevicePushService(this.api);
  final PickwiseApi api;
  final messages = StreamController<bool>.broadcast();
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  String? _token, _owner;
  int _generation = 0;
  String? status;
  bool pendingOpen = false;
  Future<void> enable(String owner, {bool requestPermission = true}) async {
    final generation = ++_generation, epoch = api.sessionEpoch;
    final server = await api.request('GET', '/api/v1/me/push-status');
    if (generation != _generation || epoch != api.sessionEpoch) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    if (generation != _generation || epoch != api.sessionEpoch) return;
    FirebaseMessaging.onBackgroundMessage(pickWiseBackgroundMessage);
    final messaging = FirebaseMessaging.instance;
    final settings = requestPermission
        ? await messaging.requestPermission()
        : await messaging.getNotificationSettings();
    if (generation != _generation || epoch != api.sessionEpoch) return;
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw const ApiException(0, '기기 설정에서 알림을 허용해주세요.');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await messaging.getAPNSToken() == null) {
      throw const ApiException(
        0,
        'Apple APNs 토큰을 아직 받지 못했어요. 서명·푸시 설정과 기기를 확인해주세요.',
      );
    }
    if (generation != _generation || epoch != api.sessionEpoch) return;
    await messaging.setAutoInitEnabled(true);
    final registered = Completer<String>();
    await _tokens?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    _tokens = messaging.onRegistered.listen((fid) async {
      if (generation != _generation || epoch != api.sessionEpoch) return;
      if (!registered.isCompleted) {
        registered.complete(fid);
        return;
      }
      try {
        await _bind(fid, epoch);
        if (generation == _generation) _token = fid;
      } catch (_) {
        status = '푸시 기기 등록 갱신에 실패했어요. 다시 확인해주세요.';
      }
    });
    String fid;
    try {
      await messaging.register();
      fid = await registered.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      await _tokens?.cancel();
      rethrow;
    }
    if (generation != _generation || epoch != api.sessionEpoch) return;
    await _bind(fid, epoch);
    if (generation != _generation || epoch != api.sessionEpoch) return;
    _token = fid;
    _owner = owner;
    _foreground = FirebaseMessaging.onMessage.listen((_) {
      if (generation == _generation) messages.add(false);
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      if (generation == _generation) messages.add(true);
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null && generation == _generation) {
      pendingOpen = true;
      messages.add(true);
    }
    if (generation != _generation || epoch != api.sessionEpoch) return;
    await (await SharedPreferences.getInstance()).setBool(
      'push-enabled:$owner',
      true,
    );
    status = server['configured'] == true
        ? '기기 푸시가 연결됐어요.'
        : '기기는 등록됐어요. 서버 Firebase 발송 인증은 아직 설정이 필요해요.';
  }

  Future<void> _bind(String token, int epoch) async {
    if (epoch != api.sessionEpoch) return;
    await api.request('PUT', '/api/v1/me/push-device', {
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
    });
  }

  Future<void> restore(String owner) async {
    try {
      if ((await SharedPreferences.getInstance()).getBool(
            'push-enabled:$owner',
          ) ==
          true) {
        await enable(owner, requestPermission: false);
      }
    } catch (_) {
      status = '푸시 연결을 확인하지 못했어요. 앱 알림함은 사용할 수 있어요.';
    }
  }

  Future<void> disable() async {
    final token = _token, owner = _owner;
    reset();
    if (owner != null) {
      await (await SharedPreferences.getInstance()).setBool(
        'push-enabled:$owner',
        false,
      );
    }
    if (token != null) {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.unregister();
      }
      await api.request('DELETE', '/api/v1/me/push-device', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
    }
  }

  void reset() {
    _generation++;
    status = null;
    pendingOpen = false;
    _token = null;
    _owner = null;
    unawaited(_tokens?.cancel());
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
  }

  void dispose() {
    reset();
    unawaited(messages.close());
  }
}

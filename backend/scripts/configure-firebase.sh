#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
# Firebase CLI 로그인은 사용자가 브라우저에서 승인한다. 비밀키는 이 명령에 넣지 않는다.
command -v firebase >/dev/null || { echo '공식 Firebase CLI 설치: npm install -g firebase-tools'; exit 1; }
command -v flutterfire >/dev/null || { echo '공식 FlutterFire CLI 설치: dart pub global activate flutterfire_cli'; exit 1; }
flutterfire configure --project=pickwise-ebc42 --platforms=android,ios --android-package-name=kr.appsolute.pickwise --ios-bundle-id=kr.appsolute.pickwise --out=lib/data/services/firebase_options.dart

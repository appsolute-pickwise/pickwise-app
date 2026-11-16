# PickWise 백엔드 — Docker + MySQL

Spring Boot 4.1.2, Java 21, MySQL 8.4를 사용한다. Docker Compose가 API와 DB를 함께 실행한다. 외부 배포는 아직 하지 않았다.

검증: MySQL 서버 통합 테스트 13개, Docker 서버에 연결한 Flutter 실제 HTTP 테스트 4개 통과. 세션·비교 기록은 MySQL에 저장하며 API 컨테이너 재생성 시 기존 볼륨을 유지한다. 새 인증 계약·앱 루트 진입점까지 실제 HTTP로 검증했다.

## 실행

```bash
cd backend
# 최초 실행 시에만 .env.example을 .env로 복사하고 서로 다른 비밀번호 설정
# 이 작업 환경에는 .env가 이미 생성돼 있다.
docker compose up -d --build
```

- API: `http://localhost:8080`
- 상태 확인: `http://localhost:8080/health`
- Mac의 MySQL 클라이언트: `127.0.0.1:3307`, DB `pickwise`, 사용자 `pickwise`
- DB 비밀번호: 로컬 `.env`의 `PICKWISE_DB_PASSWORD`. Git에 포함하지 않는다.
- Docker 내부 API→DB 연결 주소: `mysql:3306`

Android Studio에서 `lib/main.dart`를 일반 Run하거나 `PickWise - Docker Backend` 설정을 사용한다. 실행 인자는 필요 없다.

```bash
flutter run
```

명령은 Flutter 프로젝트 루트에서 실행한다. Android 에뮬레이터는 `http://10.0.2.2:8080`을 사용한다.

## 종료·재시작·로그

```bash
docker compose stop
docker compose start
docker compose logs --tail=100 api
```

MySQL 데이터는 `pickwise-mysql-data` 볼륨에 남는다. `down -v`는 데이터를 삭제하므로 일반 종료에 사용하지 않는다. 기존 PostgreSQL의 계정·비교 기록은 자동 이전하지 않았다. PostgreSQL 데이터는 보존돼 있고, MySQL에는 제품 20개를 새로 적재한다. 기존에 만든 테스트 계정은 MySQL에서 다시 가입해야 한다.

## API·테스트

전체 계약은 `openapi.yaml`, 최신 동작·수동 검증은 `../docs/개인화_비교_백엔드_연결.md`를 참고한다. 가격은 수동 확인 시점의 데이터이고 이미지는 Flutter 로컬 자산을 사용한다.

MySQL 초기화 시 `pickwise_test` 테스트 DB와 접근 권한도 생성된다. 다음 명령은 호스트에 Java가 있을 때 실행한다.

```bash
set -a
source .env
set +a
./mvnw test
```

Flyway는 `db/migration/mysql`을 사용한다. 이전 PostgreSQL 마이그레이션은 `db/migration/postgresql`에 기록용으로 보존했다. 서버 코드의 현재 지원 DB는 MySQL이다. 다른 DB의 Flyway 이력을 복사해서 사용하지 않는다.

실제 Flutter HTTP 연동 테스트:

```bash
flutter test --dart-define=LIVE_API_URL=http://localhost:8080 test/live_backend_test.dart
```

이 명령은 프로젝트 루트에서 실행하며 테스트 계정을 생성하므로 전용 개발 서버에만 사용한다.

## 기본 연결과 세션 변경

별도 인자 없이 iOS 시뮬레이터는 `http://localhost:8080`, Android 에뮬레이터는 `http://10.0.2.2:8080`으로 연결한다. 주소 변경 시에만 `--dart-define=PICKWISE_API_URL=...`를 사용한다. Docker가 꺼져 있으면 마지막 정상 서버 응답을 캐시로 보여주고 수신 시점과 재시도를 제공한다. 캐시도 없으면 연결 오류를 표시한다. 내장 JSON은 테스트 픽스처 전용이며 일반 실행에서는 대신 사용하지 않는다.

V3 마이그레이션은 이전 로그인 세션만 제거하여 한 번 재로그인하게 한다. 계정·제품·비교 기록과 MySQL 볼륨은 유지한다. 새 세션은 접근 15분·갱신 30일이며 갱신 때 두 토큰을 교체한다. 30일은 최초 로그인부터 고정한다. 스냅샷 도입 전 비교는 `snapshot: null`이다. 기존 V1·V2는 수정하지 않는다.

Android 디버그 실행에만 로컬 HTTP를 허용한다. 실기기·클라우드·릴리스 배포 연결은 이번 범위가 아니다.

## 실서비스 준비

공개 배포 없이 준비한 운영 Compose·HTTPS 프록시·비밀 파일·백업/복구·CI와 비밀번호 변경은 [실서비스 준비 문서](../docs/실서비스_준비_구현_및_운영.md)를 참고한다. 개발용 compose는 그대로 사용한다. 운영용 compose는 별도이며 자동 실행하지 않는다.

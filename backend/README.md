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

전체 계약은 `openapi.yaml`, 최신 동작·수동 검증은 `../docs/개인화_비교_백엔드_연결.md`를 참고한다. 가격은 마지막 정상 확인 값이며, 개발용 자동 조회를 켜면 다나와 상품 페이지의 가격으로 갱신한다. 이미지는 Flutter 로컬 자산을 사용한다.

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

## 개발용 가격 자동 갱신

개발용 `compose.yaml`은 `PICKWISE_PRICE_REFRESH_ENABLED=true`를 기본 사용한다. 서버 시작 30초 뒤 작업을 시작하고, 제품별 외부 조회는 최소 1시간 간격, 요청 간격은 2초이다. 앱은 실행·포그라운드 복귀와 사용 중 5분 간격으로 서버 카탈로그를 다시 받는다.

기존 제품별 다나와 URL의 제품 번호와 HTML JSON-LD의 `Product.sku`가 일치하는 경우에만 원화 최저가를 반영한다. 사양·이미지·저장된 비교 스냅샷은 변경하지 않는다. 마지막 정상 조회 시각은 `priceFetchedAt`, 최근 시도는 `priceAttemptedAt`, 상태는 `priceRefreshStatus`로 제공한다. 실패 시 이전 가격과 정상 확인일은 유지한다.

이 기능은 공식 가격 API가 아닌 공개 페이지 기반의 로컬 개발 검증용이다. 공개 배포용 Compose에는 활성화 변수를 추가하지 않았으며 기본 비활성이다. 페이지 접근 성공과 robots.txt 허용은 수집·재표시 이용 허락을 의미하지 않는다. 공개 운영 전 이용 조건과 공급자 승인을 확인하고, 필요하면 공식·제휴 데이터 공급원으로 교체한다. 인증 우회나 차단 회피는 하지 않는다.

갱신을 끄려면 로컬 `.env`에 `PICKWISE_PRICE_REFRESH_ENABLED=false`를 지정하고 API 컨테이너를 다시 생성한다. MySQL 볼륨은 삭제하지 않는다. 자세한 계약·검증은 [가격 자동 갱신 문서](../docs/가격_자동_갱신.md)를 참고한다.

## 상품 관리

서버에서 부여한 관리자 계정은 앱의 마이페이지 → 상품 관리에서 제품·가격·출처·사양을 등록·수정한다. 일반 계정은 관리자 API에 접근할 수 없다. 새 상품은 가격 자동 갱신이 기본 꺼짐이며 제품별로 변경할 수 있다. 버전 충돌은 409로 처리하고 기존 비교 스냅샷은 유지한다.

기존 개발 계정 권한 설정 도구는 `python3 scripts/admin_access.py grant manager@example.test`이다. `revoke`로 회수한다. 실제 이메일·비밀번호는 소스에 넣지 않는다. [상품 정보 관리 문서](../docs/상품_정보_관리.md)에 API·검증·사용 방법을 정리했다.

## 가격 변동 그래프

제품 상세에서 자동 조회·수동 입력을 분리한 7·30·90일 가격 그래프와 실제 기록을 확인한다. `GET /api/v1/products/{id}/price-history`를 추가했다. 가격 갱신과 이력 저장은 함께 성공하거나 함께 취소한다. V6는 기존의 마지막 정상 조회 값 한 건만 보존하며 없는 과거 기록은 만들지 않는다. [가격 변동 그래프 문서](../docs/가격_변동_그래프.md)에 사용 방법과 검증을 정리했다.

## 관심 제품과 목표가 알림

제품 상세에서 관심 제품·목표가를 저장하고 마이페이지에서 목록과 가격 알림함을 확인한다. V7·V8 마이그레이션은 기존 데이터를 보존하며 관심 설정·알림·기기별 발송 이력을 추가한다. 저장 이후 같은 출처의 정상 자동 관측 가격이 목표가 이하일 때 설정당 한 번 알린다. 관심 저장만 한 경우와 수동 가격 입력은 알림을 만들지 않는다.

Firebase 발송은 선택 구성인 `compose.firebase.yaml`과 `PICKWISE_FIREBASE_CREDENTIALS` 절대 경로를 사용한다. 현재 Mac은 Git 제외 `.env`의 `COMPOSE_FILE=compose.yaml:compose.firebase.yaml`로 이를 적용했다. 비밀키는 `.secrets`에만 보관하며 빌드 컨텍스트·Git·앱에 포함하지 않는다. API 인증과 앱 알림함은 구현·검증했으며 iOS 원격 푸시에는 Apple APNs 키와 서명 설정이 별도로 필요하다. [관심 제품·목표가 알림 문서](../docs/관심_제품_목표가_알림.md)에 계약·설정·실제 검증 범위와 남은 확인을 정리했다.

## 회원 탈퇴

마이페이지 → 회원 탈퇴에서 현재 비밀번호를 입력하고 삭제 안내에 동의한 뒤 최종 확인한다. `DELETE /api/v1/me/account`에 `currentPassword`를 보내며, 서버가 인증한 본인 계정만 삭제한다. 성공은 204, 비밀번호 불일치는 422, 세션 만료는 401이다. 운영 프로필에서는 IP별 분당 5회로 제한한다. 요청·응답에 비밀번호나 토큰을 기록하지 않는다.

계정과 전체 세션·취향·비교 기록·관심 제품·가격 알림·푸시 기기 연결을 한 트랜잭션으로 삭제한다. 모든 접근·갱신 토큰이 무효화된다. 공용 상품·가격 이력은 보존한다. V9 마이그레이션으로 상품 변경 이력의 작성자 연결을 nullable로 확장했으며, 관리자 탈퇴 시 이력 본문을 보존하고 작성자 연결만 제거한다. 기존 마이그레이션은 수정하지 않는다.

성공 후 앱은 보안 저장소의 세션과 해당 계정의 로컬 취향·비교 목록·푸시 선택 정보를 정리하고 첫 화면으로 돌아간다. 게스트·다른 계정의 설정은 유지한다. 실패 응답이 불명확할 때는 삭제를 자동 재전송하거나 완료로 표시하지 않는다. 비밀번호가 틀리면 로그인 상태를 유지하고 수정할 수 있다.

2026-11-17 검증: 실제 MySQL 백엔드 전체 47개, Flutter 전체 198개 성공(기존 선택 실행 5개 제외), 분석 오류 없음, Android 디버그 APK·iOS 시뮬레이터용 빌드 성공. 격리된 테스트 DB·8081 HTTP 서버에서 임시 계정 삭제·다른 계정 보존·전체 토큰 폐기·관리자 이력 익명화·같은 이메일의 새 계정 가입을 확인했다. 실제 사용자 계정을 탈퇴시키거나 Device Hub를 실행하지 않았다.

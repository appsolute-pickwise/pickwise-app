#!/usr/bin/env python3
"""개발용 Docker DB에서 기존 계정의 상품 관리자 권한을 부여·회수한다."""
import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["grant", "revoke"])
    parser.add_argument("email", help="이미 가입한 PickWise 계정 이메일")
    args = parser.parse_args()
    email = args.email.strip().lower()
    if len(email) > 254 or "@" not in email or any(ord(c) < 32 for c in email):
        parser.error("이메일 형식을 확인해주세요.")
    # SQL에 원문을 삽입하지 않고 UTF-8 hex literal로 전달한다.
    target = "CONVERT(0x" + email.encode("utf-8").hex() + " USING utf8mb4)"
    sql = ("START TRANSACTION;\n"
           f"UPDATE app_users SET is_admin={1 if args.action == 'grant' else 0} WHERE email={target};\n"
           f"SELECT id,is_admin FROM app_users WHERE email={target};\nCOMMIT;\n")
    result = subprocess.run(
        ["docker", "compose", "exec", "-T", "mysql", "sh", "-c",
         'MYSQL_PWD="$MYSQL_PASSWORD" exec mysql -h 127.0.0.1 -u pickwise --batch --skip-column-names pickwise'],
        cwd=Path(__file__).resolve().parents[1], input=sql, text=True, capture_output=True,
    )
    if result.returncode:
        raise SystemExit("권한 변경 실패: 개발용 Docker·DB 연결과 V5 마이그레이션 적용을 확인해주세요.")
    if not result.stdout.strip():
        raise SystemExit("해당 계정이 없습니다. PickWise에서 먼저 회원가입해주세요. 계정은 자동 생성하지 않았습니다.")
    print("관리자 권한을 " + ("부여했습니다." if args.action == "grant" else "회수했습니다.") + " 앱을 다시 실행해 계정을 확인해주세요.")


if __name__ == "__main__":
    main()

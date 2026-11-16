import 'package:flutter/material.dart';

import '../widgets/authentication_form.dart';
import '../widgets/auth_page_layout.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthPageLayout(
    title: '회원가입',
    description: '이메일과 비밀번호를 등록해주세요.',
    child: AuthenticationForm(
      register: true,
      onAuthenticated: () => Navigator.of(context).pop(),
      footerBuilder: (busy) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('이미 계정이 있어요 · 로그인', style: TextStyle(fontSize: 13)),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../widgets/authentication_form.dart';
import '../widgets/auth_page_layout.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.onGuest});
  final VoidCallback? onGuest;

  @override
  Widget build(BuildContext context) => AuthPageLayout(
    title: '로그인',
    description: '나의 기준과 저장한 비교를 이어보세요.',
    child: AuthenticationForm(
      footerBuilder: (busy) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 54),
              foregroundColor: const Color(0xFF165A4B),
              side: const BorderSide(color: Color(0xFFE1E8E3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            onPressed: busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SignUpScreen(),
                    ),
                  ),
            child: const Text('회원가입'),
          ),
          if (onGuest != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: busy ? null : onGuest,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF657181),
                minimumSize: const Size(48, 48),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '로그인 없이 둘러보기',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

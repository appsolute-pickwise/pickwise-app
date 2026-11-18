import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/pickwise_api.dart';
import '../providers/session_provider.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  late final int _epoch = context.read<SessionProvider>().generation;
  bool _agreed = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final session = context.read<SessionProvider>();
    if (_busy ||
        !_agreed ||
        session.generation != _epoch ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('정말 탈퇴할까요?'),
        content: const Text('계정과 저장한 기록이 삭제되며 복구할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || session.generation != _epoch) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.deleteAccount(_password.text);
      if (!mounted) return;
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('회원 탈퇴가 완료됐어요.')));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : '응답을 확인하지 못했어요. 다시 로그인해 계정 상태를 확인해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final sameSession = session.loggedIn && session.generation == _epoch;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('회원 탈퇴')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: sameSession
                ? Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '탈퇴 전에 확인해주세요.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '계정, 기본 취향, 저장한 비교, 관심 제품과 가격 알림이 삭제돼요. 모든 기기에서 로그아웃되며 삭제한 정보는 복구할 수 없어요.',
                        ),
                        if (session.isAdmin) ...[
                          const SizedBox(height: 12),
                          const Text(
                            '등록한 공용 상품과 상품 변경 이력은 유지되며, 작성자 연결은 제거돼요.',
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: '현재 비밀번호',
                          ),
                          validator: (value) =>
                              value == null || value.length < 8
                              ? '최소 8자 이상 입력해주세요.'
                              : value.length > 128
                              ? '128자 이내로 입력해주세요.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _agreed,
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => _agreed = value ?? false),
                          title: const Text('삭제되는 정보와 복구할 수 없다는 점을 확인했어요.'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, semanticsLabel: _error),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy || !_agreed ? null : _delete,
                          child: Text(_busy ? '탈퇴 처리 중…' : '회원 탈퇴'),
                        ),
                      ],
                    ),
                  )
                : Text(_error ?? '로그인이 변경됐어요. 이전 화면에서 다시 확인해주세요.'),
          ),
        ),
      ),
    );
  }
}

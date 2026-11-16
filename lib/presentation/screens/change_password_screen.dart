import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/pickwise_api.dart';
import '../providers/session_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _next = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionProvider>().changePassword(
        _current.text,
        _next.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 변경했어요. 새 비밀번호로 다시 로그인해주세요.')),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : '응답을 확인하지 못했어요. 새 비밀번호로 로그인을 확인해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validate(String? value) => value == null || value.length < 8
      ? '최소 8자 이상 입력해주세요.'
      : value.length > 128
      ? '128자 이내로 입력해주세요.'
      : null;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '변경하면 모든 기기에서 로그아웃돼요.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF657181)),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _current,
                  enabled: !_busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '현재 비밀번호'),
                  validator: _validate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _next,
                  enabled: !_busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '새 비밀번호',
                    helperText: '최소 8자 이상 입력해주세요.',
                  ),
                  validator: _validate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                  validator: (value) =>
                      value == _next.text ? null : '비밀번호가 일치하지 않아요.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? '변경 중…' : '비밀번호 변경'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

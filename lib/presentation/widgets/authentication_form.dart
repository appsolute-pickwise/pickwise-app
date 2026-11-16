import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/pickwise_api.dart';
import '../providers/session_provider.dart';

class AuthenticationForm extends StatefulWidget {
  const AuthenticationForm({
    super.key,
    this.register = false,
    this.onAuthenticated,
    this.footerBuilder,
  });

  final bool register;
  final VoidCallback? onAuthenticated;
  final Widget Function(bool busy)? footerBuilder;

  @override
  State<AuthenticationForm> createState() => _AuthenticationFormState();
}

class _AuthenticationFormState extends State<AuthenticationForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionProvider>().login(
        _email.text.trim(),
        _password.text,
        register: widget.register,
      );
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      if (context.read<SessionProvider>().loggedIn) {
        widget.onAuthenticated?.call();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : '로그인 정보를 안전하게 저장하거나 서버에 연결하지 못했어요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
          filled: true,
          fillColor: const Color(0xFFF5F6F8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 19,
          ),
          labelStyle: const TextStyle(fontSize: 15, color: Color(0xFF657181)),
          floatingLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF165A4B),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE1E8E3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF165A4B), width: 1.4),
          ),
        ),
      ),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                style: const TextStyle(fontSize: 15, color: Color(0xFF191F28)),
                decoration: const InputDecoration(labelText: '이메일'),
                validator: (value) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value?.trim() ?? '')
                    ? null
                    : '이메일 주소를 확인해주세요.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: widget.register
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: [
                  widget.register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onFieldSubmitted: (_) {
                  if (!widget.register) _submit();
                },
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  helperText: '최소 8자 이상 입력해주세요.',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return '비밀번호는 최소 8자 이상 입력해주세요.';
                  }
                  if (value.length > 128) {
                    return '비밀번호는 128자 이내로 입력해주세요.';
                  }
                  return null;
                },
              ),
              if (widget.register) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmation,
                  enabled: !_busy,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: '비밀번호 확인'),
                  validator: (value) =>
                      value == _password.text ? null : '비밀번호가 일치하지 않아요.',
                ),
              ],
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                alignment: Alignment.topLeft,
                child: _error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(48, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(widget.register ? '가입하기' : '로그인'),
              ),
              if (widget.footerBuilder != null) widget.footerBuilder!(_busy),
            ],
          ),
        ),
      ),
    ),
  );
}

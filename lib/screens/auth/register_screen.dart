import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../providers/auth_provider.dart';

/// Màn đăng ký — backend yêu cầu name (2–80 ký tự), password (8–64 ký tự).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameC     = TextEditingController();
  final _emailC    = TextEditingController();
  final _passwordC = TextEditingController();
  bool _obscure    = true;
  bool _loading    = false;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authStateProvider.notifier).register(
            name:     _nameC.text.trim(),
            email:    _emailC.text.trim(),
            password: _passwordC.text,
          );
      // Thành công → authStateProvider đổi trạng thái → router tự redirect về '/'
    } on ApiException catch (e) {
      _showError(apiErrorMessage(e));
    } catch (_) {
      _showError('Đã có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:  Text(message),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Chào mừng đến ShopSnap!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Tạo tài khoản để đồng bộ dữ liệu lên đám mây',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameC,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) {
                    final name = v?.trim() ?? '';
                    if (name.isEmpty) return 'Vui lòng nhập họ tên';
                    if (name.length < 2) return 'Họ tên cần ít nhất 2 ký tự';
                    if (name.length > 80) return 'Họ tên tối đa 80 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_outlined),
                  ),
                  validator: (v) {
                    final email = v?.trim() ?? '';
                    if (email.isEmpty) return 'Vui lòng nhập email';
                    if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(email)) {
                      return 'Email chưa đúng định dạng';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordC,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu (tối thiểu 8 ký tự)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final pass = v ?? '';
                    if (pass.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (pass.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự';
                    if (pass.length > 64) return 'Mật khẩu tối đa 64 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Đăng ký'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản?',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Đăng nhập',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

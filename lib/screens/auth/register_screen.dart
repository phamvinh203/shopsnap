import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/ui.dart';

/// Màn đăng ký — backend yêu cầu name (2–80 ký tự), password (8–64 ký tự).
/// Lỗi API hiện qua khối lỗi chuẩn (AppSnackBar + `api_error_messages`).
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

  /// Khối lỗi chuẩn — microcopy tiếng Việt từ `api_error_messages.dart`,
  /// KHÔNG hiển thị text exception/code raw.
  void _showError(String message) {
    AppSnackBar.show(context: context, message: message, tone: AppSnackBarTone.danger);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tạo tài khoản',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Chào mừng đến ShopSnap!',
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              // Auth gate mềm — đăng ký là tuỳ chọn để đồng bộ, không phải điều
              // kiện dùng app; giữ thông điệp trung thực về việc lưu local.
              Text(
                'Tạo tài khoản nếu bạn muốn đồng bộ dữ liệu giữa các thiết bị',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                key: const Key('registerScreen_nameField'),
                controller: _nameC,
                label: 'Họ và tên',
                hint: 'VD: Nguyễn Văn A',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final name = v?.trim() ?? '';
                  if (name.isEmpty) return 'Vui lòng nhập họ tên';
                  if (name.length < 2) return 'Họ tên cần ít nhất 2 ký tự';
                  if (name.length > 80) return 'Họ tên tối đa 80 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('registerScreen_emailField'),
                controller: _emailC,
                label: 'Email',
                hint: 'email@cuaban.com',
                prefixIcon: Icons.alternate_email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final email = v?.trim() ?? '';
                  if (email.isEmpty) return 'Vui lòng nhập email';
                  if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(email)) {
                    return 'Email chưa đúng định dạng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('registerScreen_passwordField'),
                controller: _passwordC,
                label: 'Mật khẩu (tối thiểu 8 ký tự)',
                obscure: _obscure,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) {
                  final pass = v ?? '';
                  if (pass.isEmpty) return 'Vui lòng nhập mật khẩu';
                  if (pass.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự';
                  if (pass.length > 64) return 'Mật khẩu tối đa 64 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                key: const Key('registerScreen_submitButton'),
                label: 'Đăng ký',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Đã có tài khoản?', style: context.text.bodyMedium),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Đăng nhập'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/ui.dart';

/// Màn đăng nhập — validate form, gọi AuthNotifier.login, lỗi API hiện qua
/// khối lỗi chuẩn (AppSnackBar + `api_error_messages`, không raw exception).
///
/// Auth gate mềm: màn này chỉ là LỰA CHỌN, không phải cửa ải — user có thể
/// "Dùng app trước" mà không tạo tài khoản.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailC    = TextEditingController();
  final _passwordC = TextEditingController();
  bool _obscure    = true;
  bool _loading    = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authStateProvider.notifier).login(
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthHeader(
                  subtitle: 'Đăng nhập để tiếp tục theo dõi chi tiêu',
                ),
                const SizedBox(height: AppSpacing.xxxl),
                AppTextField(
                  key: const Key('loginScreen_emailField'),
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
                  key: const Key('loginScreen_passwordField'),
                  controller: _passwordC,
                  label: 'Mật khẩu',
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
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  key: const Key('loginScreen_submitButton'),
                  label: 'Đăng nhập',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Chưa có tài khoản?', style: context.text.bodyMedium),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Đăng ký'),
                    ),
                  ],
                ),
                // Auth gate mềm — không ép đăng nhập: cho thử app trước.
                GhostButton(
                  key: const Key('loginScreen_skipButton'),
                  label: 'Dùng app trước, đăng nhập sau',
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header chung của màn auth — logo + tiêu đề brand + phụ đề.
class _AuthHeader extends StatelessWidget {
  final String subtitle;
  const _AuthHeader({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: context.snap.tintPrimary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Icon(Icons.shopping_cart_outlined,
              color: context.cs.primary, size: 36),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('ShopSnap',
            style: context.text.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: context.text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

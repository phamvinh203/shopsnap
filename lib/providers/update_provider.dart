import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_update_model.dart';
import '../services/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

class UpdateState {
  final AsyncValue<AppUpdateInfo?> info;
  final bool dismissed;

  const UpdateState({
    required this.info,
    this.dismissed = false,
  });

  UpdateState copyWith({
    AsyncValue<AppUpdateInfo?>? info,
    bool? dismissed,
  }) {
    return UpdateState(
      info: info ?? this.info,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _service;

  UpdateNotifier(this._service) : super(const UpdateState(info: AsyncValue.data(null)));

  /// Tự động kiểm tra bản cập nhật (chỉ hiện popup nếu chưa bấm 'Để sau' trong phiên này)
  Future<AppUpdateInfo?> checkSilently() async {
    if (state.dismissed) return null;

    try {
      final info = await _service.checkForUpdate(forceRefresh: false);
      state = state.copyWith(info: AsyncValue.data(info));
      return info;
    } catch (e, st) {
      state = state.copyWith(info: AsyncValue.error(e, st));
      return null;
    }
  }

  /// Kiểm tra thủ công (người dùng bấm nút trong cài đặt/hồ sơ)
  Future<AppUpdateInfo> checkManually() async {
    state = state.copyWith(
      info: const AsyncValue.loading(),
      dismissed: false, // Reset cờ bỏ qua khi bấm kiểm tra thủ công
    );

    try {
      final info = await _service.checkForUpdate(forceRefresh: true);
      state = state.copyWith(info: AsyncValue.data(info));
      return info;
    } catch (e, st) {
      state = state.copyWith(info: AsyncValue.error(e, st));
      rethrow;
    }
  }

  /// Bỏ qua thông báo trong phiên này
  void dismiss() {
    state = state.copyWith(dismissed: true);
  }

  /// Khởi chạy tải APK
  Future<bool> download(String url) async {
    return await _service.launchDownload(url);
  }
}

final appUpdateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  final service = ref.watch(updateServiceProvider);
  return UpdateNotifier(service);
});

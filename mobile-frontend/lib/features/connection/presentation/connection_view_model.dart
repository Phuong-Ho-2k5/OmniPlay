import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/health_repository.dart';
import 'connection_state.dart';

class ConnectionViewModel extends ChangeNotifier {
  ConnectionViewModel(this._repository);
  final HealthRepository _repository;
  ConnectionState _state = const ConnectionState(ConnectionStatus.idle);
  bool _disposed = false;
  ConnectionState get state => _state;

  Future<void> checkConnection() async {
    if (_disposed || _state.status == ConnectionStatus.loading) return;
    _update(const ConnectionState(ConnectionStatus.loading));
    try {
      await _repository.check();
      _update(const ConnectionState(ConnectionStatus.success));
    } on ApiException catch (error) {
      final message = switch (error.kind) {
        ApiFailureKind.network =>
          'Không thể kết nối. Hãy kiểm tra mạng và thử lại.',
        ApiFailureKind.timeout =>
          'Kết nối mất quá nhiều thời gian. Vui lòng thử lại.',
        ApiFailureKind.http =>
          error.statusCode == 503
              ? 'Dịch vụ tạm thời chưa sẵn sàng. Vui lòng thử lại.'
              : 'Máy chủ chưa thể xử lý yêu cầu. Vui lòng thử lại.',
        ApiFailureKind.invalidResponse =>
          'Phản hồi chưa hợp lệ. Vui lòng thử lại.',
      };
      _update(ConnectionState(ConnectionStatus.error, message: message));
    } catch (_) {
      _update(
        const ConnectionState(
          ConnectionStatus.error,
          message: 'Không thể hoàn tất kiểm tra. Vui lòng thử lại.',
        ),
      );
    }
  }

  void _update(ConnectionState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

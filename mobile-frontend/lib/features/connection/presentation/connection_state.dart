enum ConnectionStatus { idle, loading, success, error }

class ConnectionState {
  const ConnectionState(this.status, {this.message});
  final ConnectionStatus status;
  final String? message;
}

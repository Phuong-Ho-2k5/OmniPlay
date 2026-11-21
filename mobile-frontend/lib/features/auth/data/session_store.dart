import 'package:flutter/foundation.dart';

import '../models/token_pair.dart';

abstract interface class SessionStore {
  TokenPair? get tokens;
  void replace(TokenPair pair);
  void clear();
}

class InMemorySessionStore extends ChangeNotifier implements SessionStore {
  TokenPair? _tokens;
  bool _disposed = false;
  @override
  TokenPair? get tokens => _tokens;
  @override
  void replace(TokenPair pair) {
    if (_disposed) return;
    _tokens = pair;
    notifyListeners();
  }

  @override
  void clear() {
    if (_disposed || _tokens == null) return;
    _tokens = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tokens = null;
    super.dispose();
  }
}

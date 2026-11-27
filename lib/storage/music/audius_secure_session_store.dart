import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/music/audius_account.dart';

final class AudiusSecureSessionStore implements AudiusSessionStore {
  const AudiusSecureSessionStore();

  static const _key = 'musaic.audius.oauth.v1';
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String session) =>
      _storage.write(key: _key, value: session);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

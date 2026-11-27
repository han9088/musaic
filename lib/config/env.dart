import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', requireEnvFile: false)
abstract final class Env {
  @EnviedField(varName: 'AUDIUS_API_KEY', defaultValue: '', obfuscate: true)
  static final String audiusApiKey = _Env.audiusApiKey;
}

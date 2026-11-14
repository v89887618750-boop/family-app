/// Настройки подключения к Supabase.
///
/// Значения передаются при сборке, а не хранятся в коде:
///
///   flutter build apk --release \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// В GitHub Actions они берутся из репозиторных секретов
/// (Settings → Secrets and variables → Actions).
///
/// Если ключи не переданы — приложение полностью работает локально,
/// а экран синхронизации честно сообщает, что она не настроена.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Ставится в `true` после успешного `Supabase.initialize` в main().
  /// Пока false — обращаться к Supabase нельзя (иначе исключение).
  static bool ready = false;

  /// Ключи переданы И клиент инициализирован.
  static bool get isReady => isConfigured && ready;
}

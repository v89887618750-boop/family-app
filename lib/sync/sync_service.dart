import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import 'supabase_config.dart';

/// Ошибка синхронизации с человекочитаемым текстом.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Результат одного цикла синхронизации.
class SyncResult {
  SyncResult({
    this.pulled = 0,
    this.pushed = 0,
    this.errors = const <String>[],
  });

  final int pulled;
  final int pushed;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get hadChanges => pulled > 0 || pushed > 0;
}

/// Синхронизация локальной SQLite-базы с Supabase.
///
/// Сознательно НЕ используется `supabase_flutter`: он тянет нативные плагины
/// (app_links), которые ломают сборку на Flutter 3.24 / AGP 8.3.
/// Здесь всё сделано на чистом HTTP — без единого нативного плагина:
///   * вход/регистрация — Supabase Auth (`/auth/v1/token`, `/auth/v1/signup`);
///   * данные          — PostgREST (`/rest/v1/family_data`).
///
/// Принцип синхронизации: локальная база главная, приложение работает офлайн.
/// У каждой строки есть `sync_id` (UUID) и `updated_at` (мс epoch), которые
/// проставляют SQLite-триггеры; удаления фиксируются в `sync_tombstones`.
/// Конфликты решаются по принципу «побеждает более поздняя правка».
class SyncService {
  static const String _remoteTable = 'family_data';
  static const Duration _timeout = Duration(seconds: 30);

  // Ключи для хранения сессии между запусками.
  static const String _kAccess = 'sb_access_token';
  static const String _kRefresh = 'sb_refresh_token';
  static const String _kExpires = 'sb_expires_at';
  static const String _kEmail = 'sb_email';

  static String? _accessToken;
  static String? _refreshToken;
  static int _expiresAtMs = 0;
  static String? _email;

  /// Какие поля каждой таблицы попадают в облако.
  /// Порядок таблиц в [DatabaseHelper.syncTables] важен: сначала те,
  /// на которые ссылаются другие (birthdays → family_members → relations).
  static const Map<String, List<String>> _payloadColumns = <String, List<String>>{
    'tasks': <String>[
      'title',
      'category',
      'periodicity',
      'isCompleted',
      'due_date',
      'due_time',
      'reading_value',
    ],
    'purchases': <String>[
      'title',
      'category',
      'periodicity',
      'isCompleted',
      'note',
    ],
    'birthdays': <String>[
      'name',
      'date',
      'category',
      'remind_days',
      'photo_path',
    ],
    'gifts': <String>[
      'title',
      'forWhom',
      'category',
      'isBought',
      'note',
      'photo_path',
      'reserved_by',
    ],
    'categories': <String>['name'],
    'notes': <String>[
      'title',
      'content',
      'date',
      'color',
      'category',
      'photo_path',
    ],
    'family_members': <String>['name', 'relation', 'photo_path'],
    'relations': <String>['type'],
    'meter_readings': <String>['reading_value', 'date'],
  };

  // ---------------------------------------------------------------------------
  // Инициализация и состояние сессии
  // ---------------------------------------------------------------------------

  /// Загружает сохранённую сессию. Вызывается один раз в main().
  static const String _kUrlOverride = 'sb_url_override';
  static const String _kKeyOverride = 'sb_key_override';

  static String? _urlOverride;
  static String? _keyOverride;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _urlOverride = prefs.getString(_kUrlOverride);
    _keyOverride = prefs.getString(_kKeyOverride);
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
    _expiresAtMs = prefs.getInt(_kExpires) ?? 0;
    _email = prefs.getString(_kEmail);

    SupabaseConfig.ready = isConfigured;
  }

  /// Адрес сервера: ручная настройка с телефона важнее значения из сборки.
  static String get effectiveUrl => (_urlOverride ?? SupabaseConfig.url).trim();

  /// Anon-ключ: тоже можно переопределить на устройстве.
  static String get effectiveAnonKey =>
      (_keyOverride ?? SupabaseConfig.anonKey).trim();

  /// Явно задать адрес и ключ на устройстве — без пересборки APK.
  /// Пустая строка сбрасывает переопределение.
  static Future<void> saveConnection({
    required String url,
    required String anonKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    var cleanUrl = url.trim();
    while (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    final cleanKey = anonKey.trim();

    if (cleanUrl.isEmpty) {
      await prefs.remove(_kUrlOverride);
    } else {
      await prefs.setString(_kUrlOverride, cleanUrl);
    }

    if (cleanKey.isEmpty) {
      await prefs.remove(_kKeyOverride);
    } else {
      await prefs.setString(_kKeyOverride, cleanKey);
    }

    _urlOverride = cleanUrl.isEmpty ? null : cleanUrl;
    _keyOverride = cleanKey.isEmpty ? null : cleanKey;
    SupabaseConfig.ready = isConfigured;
  }

  static bool get isConfigured =>
      effectiveUrl.isNotEmpty && effectiveAnonKey.isNotEmpty;

  static bool get isSignedIn => isConfigured && (_accessToken ?? '').isNotEmpty;

  static String? get currentEmail => _email;

  static Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString(_kAccess, _accessToken!);
    } else {
      await prefs.remove(_kAccess);
    }
    if (_refreshToken != null) {
      await prefs.setString(_kRefresh, _refreshToken!);
    } else {
      await prefs.remove(_kRefresh);
    }
    await prefs.setInt(_kExpires, _expiresAtMs);
    if (_email != null) {
      await prefs.setString(_kEmail, _email!);
    }
  }

  // ---------------------------------------------------------------------------
  // Аккаунт семьи (один общий логин на всю семью)
  // ---------------------------------------------------------------------------

  static Future<void> signIn(String email, String password) async {
    if (!isConfigured) {
      throw const SyncException('Синхронизация не настроена на этой сборке.');
    }
    final uri = Uri.parse('${effectiveUrl}/auth/v1/token?grant_type=password');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _baseHeaders(),
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(_timeout);
    } catch (e) {
      throw SyncException(_networkErrorText(e));
    }

    _applyAuthResponse(response, fallbackEmail: email.trim());
    await _persistSession();
  }

  static Future<void> signUp(String email, String password) async {
    if (!isConfigured) {
      throw const SyncException('Синхронизация не настроена на этой сборке.');
    }
    final uri = Uri.parse('${effectiveUrl}/auth/v1/signup');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _baseHeaders(),
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(_timeout);
    } catch (e) {
      throw SyncException(_networkErrorText(e));
    }

    _applyAuthResponse(
      response,
      fallbackEmail: email.trim(),
      missingTokenHint: 'Аккаунт создан, но Supabase требует подтверждение '
          'почты. В Supabase откройте Authentication → Sign In / Up → Email '
          'и выключите «Confirm email», затем войдите.',
    );
    await _persistSession();
  }

  static Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAtMs = 0;
    _email = null;
    await _persistSession();
  }

  static Map<String, String> _baseHeaders() {
    return <String, String>{
      'apikey': effectiveAnonKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Map<String, String> _authHeaders() {
    return <String, String>{
      'apikey': effectiveAnonKey,
      'Authorization': 'Bearer ${_accessToken ?? ''}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static void _applyAuthResponse(
    http.Response response, {
    required String fallbackEmail,
    String? missingTokenHint,
  }) {
    final body = _decodeMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = body['access_token'];
      if (token is! String || token.isEmpty) {
        throw SyncException(
          missingTokenHint ??
              'Supabase не вернул токен доступа. Включено подтверждение почты? '
                  'Выключите «Confirm email» в Authentication → Sign In / Up.',
        );
      }

      _accessToken = token;
      final refresh = body['refresh_token'];
      _refreshToken = refresh is String ? refresh : null;

      final expiresIn = body['expires_in'];
      final seconds = expiresIn is num ? expiresIn.toInt() : 3600;
      _expiresAtMs =
          DateTime.now().millisecondsSinceEpoch + seconds * 1000;

      _email = _extractEmail(body) ?? fallbackEmail;
      return;
    }

    throw SyncException(_authErrorText(response, body));
  }

  static String? _extractEmail(Map<String, dynamic> body) {
    final direct = body['email'];
    if (direct is String && direct.isNotEmpty) return direct;

    final user = body['user'];
    if (user is Map) {
      final email = user['email'];
      if (email is String && email.isNotEmpty) return email;
    }
    return null;
  }

  static String _authErrorText(
    http.Response response,
    Map<String, dynamic> body,
  ) {
    final raw = body['error_description'] ??
        body['msg'] ??
        body['message'] ??
        body['error'];
    final text = raw is String ? raw : '';

    if (text.contains('Invalid login credentials')) {
      return 'Неверный e-mail или пароль.';
    }
    if (text.contains('already registered') ||
        text.contains('User already registered')) {
      return 'Такая почта уже зарегистрирована — нажмите «Войти» с этим паролем.';
    }
    if (text.contains('Password should be')) {
      return 'Слишком простой пароль: нужно не меньше 6 символов.';
    }
    if (text.contains('Email not confirmed')) {
      return 'Почта не подтверждена. Отключите «Confirm email» в Supabase.';
    }
    if (text.contains('Invalid API key') || response.statusCode == 401) {
      return 'Неверный anon-ключ (SUPABASE_ANON_KEY). Проверьте секрет в GitHub.';
    }

    if (text.isNotEmpty) return text;
    return 'Ошибка ${response.statusCode}. Проверьте SUPABASE_URL и anon-ключ.';
  }

  // ---------------------------------------------------------------------------
  // Обмен данными
  // ---------------------------------------------------------------------------

  /// Полный цикл: забрать облако → отправить локальные изменения.
  static Future<SyncResult> syncAll({bool full = false}) async {
    if (!isSignedIn) {
      throw const SyncException('Сначала войдите в аккаунт семьи.');
    }

    final db = await DatabaseHelper.instance.database;
    final errors = <String>[];

    final sincePull = full ? 0 : await _readMeta(db, 'last_pull');
    final sincePush = full ? 0 : await _readMeta(db, 'last_push');

    final pulled = await _pull(db, sincePull, errors);
    final pushed = await _push(db, sincePush, errors);

    return SyncResult(pulled: pulled, pushed: pushed, errors: errors);
  }

  /// Сбрасывает прогресс — следующий обмен пойдёт «с нуля».
  static Future<void> resetProgress() async {
    final db = await DatabaseHelper.instance.database;
    await _writeMeta(db, 'last_pull', 0);
    await _writeMeta(db, 'last_push', 0);
  }

  static Future<void> _refreshIfNeeded() async {
    if ((_accessToken ?? '').isEmpty) {
      throw const SyncException('Нужно войти в аккаунт семьи.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_expiresAtMs - now > 60000) return;

    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await signOut();
      throw const SyncException('Сессия истекла — войдите заново.');
    }

    final uri =
        Uri.parse('${effectiveUrl}/auth/v1/token?grant_type=refresh_token');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _baseHeaders(),
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(_timeout);
    } catch (e) {
      throw SyncException(_networkErrorText(e));
    }
    _applyAuthResponse(
      response,
      fallbackEmail: _email ?? '',
      missingTokenHint: 'Не удалось продлить сессию — войдите заново.',
    );
    await _persistSession();
  }

  static Future<int> _pull(Database db, int since, List<String> errors) async {
    var processed = 0;

    try {
      await _refreshIfNeeded();

      final uri = Uri.parse(
        '${effectiveUrl}/rest/v1/$_remoteTable?select=*',
      );
      final http.Response response;
      try {
        response =
            await http.get(uri, headers: _authHeaders()).timeout(_timeout);
      } catch (e) {
        throw SyncException(_networkErrorText(e));
      }

      if (response.statusCode != 200) {
        throw SyncException(_restErrorText(response));
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = <Map<String, dynamic>>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) rows.add(item);
        }
      }

      var maxUpdated = since;
      for (final row in rows) {
        try {
          await _applyRemoteRow(db, row);
        } catch (e) {
          errors.add('Получение: $e');
        }
        final updated = row['updated_at'];
        if (updated is int && updated > maxUpdated) maxUpdated = updated;
        processed++;
      }

      await _writeMeta(db, 'last_pull', maxUpdated);
    } catch (e) {
      errors.add(e is SyncException ? e.message : _networkErrorText(e));
    }

    return processed;
  }

  static Future<int> _push(Database db, int since, List<String> errors) async {
    final outgoing = <Map<String, dynamic>>[];

    try {
      for (final table in DatabaseHelper.syncTables) {
        await _collectLocalChanges(db, table, since, outgoing);
      }
      await _collectTombstones(db, since, outgoing);

      if (outgoing.isEmpty) return 0;

      await _refreshIfNeeded();

      final uri = Uri.parse(
        '${effectiveUrl}/rest/v1/$_remoteTable?on_conflict=sync_id',
      );

      for (var index = 0; index < outgoing.length; index += 200) {
        final end =
            index + 200 <= outgoing.length ? index + 200 : outgoing.length;
        final chunk = outgoing.sublist(index, end);

        final http.Response response;
        try {
          response = await http
              .post(
                uri,
                headers: <String, String>{
                  ..._authHeaders(),
                  'Prefer': 'resolution=merge-duplicates,return=minimal',
                },
                body: jsonEncode(chunk),
              )
              .timeout(_timeout);
        } catch (e) {
          throw SyncException(_networkErrorText(e));
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw SyncException(_restErrorText(response));
        }
      }

      var maxLocal = since;
      for (final item in outgoing) {
        final timestamp = item['updated_at'];
        if (timestamp is int && timestamp > maxLocal) maxLocal = timestamp;
      }
      await _writeMeta(db, 'last_push', maxLocal);

      return outgoing.length;
    } catch (e) {
      errors.add(e is SyncException ? e.message : _networkErrorText(e));
      return 0;
    }
  }

  /// Понятный текст для сетевых ошибок (DNS, таймаут, отказ подключения).
  /// В сообщение всегда попадает адрес, с которым шла попытка — чтобы
  /// опечатку в URL было видно сразу.
  static String _networkErrorText(Object error) {
    final text = error.toString();

    if (text.contains('Failed host lookup') ||
        text.contains('No address associated') ||
        text.contains('nodename nor servname')) {
      return 'Не удалось найти сервер по адресу "${effectiveUrl}". '
          'Проверьте адрес (частая причина — опечатка в project ref).';
    }
    if (text.contains('Connection refused')) {
      return 'Сервер отклонил подключение: ${effectiveUrl}';
    }
    if (text.contains('Timeout')) {
      return 'Сервер не ответил за 30 секунд: ${effectiveUrl}';
    }
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Нет связи с сервером "${effectiveUrl}". '
          'Проверьте интернет и адрес.';
    }
    return 'Ошибка сети: $text';
  }

  static String _restErrorText(http.Response response) {
    final body = _decodeMap(response.body);
    final raw = body['message'] ?? body['error_description'] ?? body['hint'];
    final text = raw is String ? raw : '';

    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Нет доступа к данным: войдите в аккаунт заново.';
    }
    if (response.statusCode == 404) {
      return 'Таблица family_data не найдена. Выполните supabase/schema.sql '
          'в Supabase → SQL Editor.';
    }
    if (text.contains('row-level security') ||
        text.contains('new row violates row-level security')) {
      return 'RLS заблокировал запись. Проверьте политики из supabase/schema.sql.';
    }
    if (text.isNotEmpty) return text;
    return 'Ошибка ${response.statusCode} при обращении к облаку.';
  }

  // ---------------------------------------------------------------------------
  // Сборка исходящих строк
  // ---------------------------------------------------------------------------

  static Future<void> _collectLocalChanges(
    Database db,
    String table,
    int since,
    List<Map<String, dynamic>> out,
  ) async {
    final rows = await db.query(
      table,
      where: 'updated_at > ?',
      whereArgs: [since],
    );

    for (final row in rows) {
      final syncId = row['sync_id'];
      if (syncId is! String || syncId.isEmpty) continue;

      final payload = <String, dynamic>{};
      for (final column in _payloadColumns[table] ?? const <String>[]) {
        payload[column] = row[column];
      }

      // Внешние ключи передаём как sync_id связанной записи:
      // локальные INTEGER id на разных устройствах разные, а sync_id — общий.
      if (table == 'family_members') {
        payload['birthday_sync_id'] =
            await _syncIdFor(db, 'birthdays', row['birthday_id']);
      } else if (table == 'meter_readings') {
        payload['task_sync_id'] =
            await _syncIdFor(db, 'tasks', row['task_id']);
      } else if (table == 'relations') {
        payload['a_sync_id'] =
            await _syncIdFor(db, 'family_members', row['a_id']);
        payload['b_sync_id'] =
            await _syncIdFor(db, 'family_members', row['b_id']);
      }

      out.add(<String, dynamic>{
        'sync_id': syncId,
        'table_name': table,
        'updated_at': row['updated_at'],
        'deleted': false,
        'payload': payload,
      });
    }
  }

  static Future<void> _collectTombstones(
    Database db,
    int since,
    List<Map<String, dynamic>> out,
  ) async {
    final rows = await db.query(
      'sync_tombstones',
      where: 'deleted_at > ?',
      whereArgs: [since],
    );

    for (final row in rows) {
      final syncId = row['sync_id'];
      if (syncId is! String || syncId.isEmpty) continue;
      final tableName = row['table_name'];

      out.add(<String, dynamic>{
        'sync_id': syncId,
        'table_name': tableName is String ? tableName : '',
        'updated_at': row['deleted_at'],
        'deleted': true,
        'payload': <String, dynamic>{},
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Применение входящих строк
  // ---------------------------------------------------------------------------

  static Future<void> _applyRemoteRow(
    Database db,
    Map<String, dynamic> remoteRow,
  ) async {
    final table = remoteRow['table_name'];
    final syncId = remoteRow['sync_id'];
    if (table is! String || syncId is! String || syncId.isEmpty) return;
    if (!_payloadColumns.containsKey(table)) return;

    final local = await _findLocalBySyncId(db, table, syncId);

    // Удаление с другого устройства.
    if (remoteRow['deleted'] == true) {
      if (local != null) {
        await db.delete(table, where: 'id = ?', whereArgs: [local['id']]);
      }
      return;
    }

    final timestamp = _asInt(remoteRow['updated_at']);
    final payloadRaw = remoteRow['payload'];
    final payload = payloadRaw is Map ? payloadRaw : const <String, dynamic>{};

    final values = <String, dynamic>{};
    for (final column in _payloadColumns[table] ?? const <String>[]) {
      if (payload.containsKey(column)) {
        values[column] = payload[column];
      }
    }

    // Внешние ключи: sync_id → локальный id.
    if (table == 'family_members') {
      values['birthday_id'] =
          await _localIdFor(db, 'birthdays', payload['birthday_sync_id']);
    } else if (table == 'meter_readings') {
      final taskId = await _localIdFor(db, 'tasks', payload['task_sync_id']);
      if (taskId == null) return; // без задачи показание бессмысленно
      values['task_id'] = taskId;
    } else if (table == 'relations') {
      final aId = await _localIdFor(db, 'family_members', payload['a_sync_id']);
      final bId = await _localIdFor(db, 'family_members', payload['b_sync_id']);
      if (aId == null || bId == null) return;
      values['a_id'] = aId;
      values['b_id'] = bId;
    }

    if (local == null) {
      values['sync_id'] = syncId;
      values['updated_at'] = timestamp > 0 ? timestamp : 1;
      await db.insert(table, values);
      return;
    }

    final localTimestamp = _asInt(local['updated_at']);
    if (timestamp > localTimestamp) {
      // updated_at передаём явно — триггер сохранит его как есть.
      values['updated_at'] = timestamp;
      await db.update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [local['id']],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Вспомогательные запросы
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // тело не JSON — ничего страшного
    }
    return <String, dynamic>{};
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<Map<String, dynamic>?> _findLocalBySyncId(
    Database db,
    String table,
    String syncId,
  ) async {
    final rows = await db.query(
      table,
      where: 'sync_id = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<String?> _syncIdFor(
    Database db,
    String table,
    Object? localId,
  ) async {
    if (localId == null) return null;
    final rows = await db.query(
      table,
      columns: ['sync_id'],
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['sync_id'];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static Future<int?> _localIdFor(
    Database db,
    String table,
    Object? syncId,
  ) async {
    if (syncId is! String || syncId.isEmpty) return null;
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'sync_id = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  static Future<int> _readMeta(Database db, String key) async {
    final rows = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return _asInt(rows.first['value']);
  }

  static Future<void> _writeMeta(Database db, String key, int value) async {
    await db.insert(
      'sync_meta',
      <String, dynamic>{'key': key, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// Принцип: локальная база — главный источник, приложение работает офлайн.
/// Обмен построен на трёх полях каждой строки:
///   * `sync_id` — одинаковый идентификатор на всех устройствах;
///   * `updated_at` — время последнего изменения (мс epoch);
///   * надгробия в `sync_tombstones` — для удалений.
///
/// Конфликты решаются по принципу «побеждает более позднее изменение»
/// (last-write-wins по строке): сначала забираем облако, потом отправляем своё.
class SyncService {
  /// Таблица в Supabase, где лежат данные семьи.
  static const String _remoteTable = 'family_data';

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

  static SupabaseClient get _client => Supabase.instance.client;

  /// Ключи переданы и клиент Supabase инициализирован.
  static bool get isConfigured => SupabaseConfig.isReady;

  static bool get isSignedIn {
    if (!isConfigured) return false;
    return _client.auth.currentSession != null;
  }

  static String? get currentEmail {
    if (!isSignedIn) return null;
    return _client.auth.currentUser?.email;
  }

  // ---------------------------------------------------------------------------
  // Аккаунт семьи (один общий логин на всю семью)
  // ---------------------------------------------------------------------------

  static Future<void> signIn(String email, String password) async {
    if (!isConfigured) {
      throw const SyncException('Синхронизация не настроена на этой сборке.');
    }
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw SyncException(_authMessage(e.message));
    }
  }

  static Future<void> signUp(String email, String password) async {
    if (!isConfigured) {
      throw const SyncException('Синхронизация не настроена на этой сборке.');
    }
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        throw const SyncException(
          'Аккаунт создан, но Supabase требует подтверждение почты. '
          'В Supabase откройте Authentication → Sign In / Up → Email '
          'и выключите «Confirm email», затем попробуйте войти.',
        );
      }
    } on AuthException catch (e) {
      throw SyncException(_authMessage(e.message));
    }
  }

  static Future<void> signOut() async {
    if (!isConfigured) return;
    await _client.auth.signOut();
  }

  static String _authMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Неверный e-mail или пароль.';
    }
    if (message.contains('already registered')) {
      return 'Такая почта уже зарегистрирована — войдите с этим паролем.';
    }
    if (message.contains('Password should be')) {
      return 'Слишком простой пароль: нужно не меньше 6 символов.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Почта не подтверждена. Отключите «Confirm email» в Supabase.';
    }
    return message;
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

  static Future<int> _pull(Database db, int since, List<String> errors) async {
    var processed = 0;

    try {
      final data = await _client.from(_remoteTable).select();
      final rows = (data as List).cast<Map<String, dynamic>>();
      var maxUpdated = since;

      for (final row in rows) {
        try {
          await _applyRemoteRow(db, row);
        } catch (e) {
          errors.add('Получение ($e)');
        }
        final updated = row['updated_at'];
        if (updated is int && updated > maxUpdated) maxUpdated = updated;
        processed++;
      }

      await _writeMeta(db, 'last_pull', maxUpdated);
    } catch (e) {
      errors.add('Не удалось получить данные: $e');
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

      for (var index = 0; index < outgoing.length; index += 200) {
        final end = index + 200 <= outgoing.length
            ? index + 200
            : outgoing.length;
        final chunk = outgoing.sublist(index, end);
        await _client.from(_remoteTable).upsert(chunk, onConflict: 'sync_id');
      }

      var maxLocal = since;
      for (final item in outgoing) {
        final timestamp = item['updated_at'];
        if (timestamp is int && timestamp > maxLocal) maxLocal = timestamp;
      }
      await _writeMeta(db, 'last_push', maxLocal);

      return outgoing.length;
    } catch (e) {
      errors.add('Не удалось отправить данные: $e');
      return 0;
    }
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

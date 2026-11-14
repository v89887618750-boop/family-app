import 'package:sqflite/sqflite.dart';

/// Удаление записей с фиксацией «надгробий».
///
/// Зачем: если просто удалить строку, при синхронизации она приедет обратно
/// с другого устройства. Поэтому перед удалением мы запоминаем `sync_id`
/// в `sync_tombstones`, а модуль синхронизации отправляет эти записи
/// в облако как `deleted = true`.
///
/// Все места в приложении, где удаляются данные, должны использовать
/// эти методы вместо `db.delete(...)`.
class SyncDb {
  /// Удаляет одну строку по локальному `id`.
  static Future<void> deleteRow(
    Database db,
    String table,
    Object? localId,
  ) async {
    if (localId == null) return;
    await deleteWhere(
      db,
      table,
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Удаляет набор строк по условию, запоминая их sync_id.
  static Future<void> deleteWhere(
    Database db,
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await db.query(
      table,
      columns: ['sync_id'],
      where: where,
      whereArgs: whereArgs,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      await _recordTombstone(db, table, row['sync_id'], now);
    }

    await db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Явно помечает строку удалённой (если удаление делается вручную).
  static Future<void> recordTombstoneBySyncId(
    Database db,
    String table,
    String syncId,
  ) async {
    await _recordTombstone(
      db,
      table,
      syncId,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> _recordTombstone(
    Database db,
    String table,
    Object? syncId,
    int deletedAt,
  ) async {
    if (syncId is! String || syncId.isEmpty) return;
    await db.insert(
      'sync_tombstones',
      <String, dynamic>{
        'sync_id': syncId,
        'table_name': table,
        'deleted_at': deletedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

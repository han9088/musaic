import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Stores the user's cover images independently of the scanned music index.
final class CustomArtworkStore extends ChangeNotifier {
  CustomArtworkStore({this._factory, this._path});

  static final instance = CustomArtworkStore();
  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _opening;
  final _revisions = <String, ({int version, bool hasImage})>{};

  int? revisionOf(String key) {
    final entry = _revisions[key];
    return entry != null && entry.hasImage ? entry.version : null;
  }

  Future<Database> _open() =>
      _opening ??= _openDatabase().onError<Object>((error, stack) {
        _opening = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<Database> _openDatabase() async {
    final factory = _factory ?? databaseFactory;
    return factory.openDatabase(
      _path ?? '${await factory.getDatabasesPath()}/custom_artwork.sqlite',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE covers (id TEXT PRIMARY KEY, revision INTEGER NOT NULL, image BLOB NOT NULL)',
        ),
      ),
    );
  }

  Future<void> load() async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT id, revision, length(image) > 0 AS has_image FROM covers',
    );
    for (final row in rows) {
      _revisions.putIfAbsent(
        row['id'] as String,
        () =>
            (version: row['revision'] as int, hasImage: row['has_image'] == 1),
      );
    }
    if (rows.isNotEmpty) notifyListeners();
  }

  Future<Uint8List?> read(String key, int revision) async {
    final db = await _open();
    final rows = await db.query(
      'covers',
      columns: ['image'],
      where: 'id = ? AND revision = ?',
      whereArgs: [key, revision],
    );
    return rows.firstOrNull?['image'] as Uint8List?;
  }

  Future<void> save(String key, Uint8List image) => _write(key, image);

  // Preserve the revision so a later upload cannot reuse an old render cache key.
  Future<void> restore(String key) => _write(key, Uint8List(0));

  Future<void> _write(String key, Uint8List image) async {
    final db = await _open();
    final revision = await db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR REPLACE INTO covers (id, revision, image) '
        'VALUES (?, COALESCE((SELECT revision + 1 FROM covers WHERE id = ?), 1), ?)',
        [key, key, image],
      );
      final rows = await txn.query(
        'covers',
        columns: ['revision'],
        where: 'id = ?',
        whereArgs: [key],
      );
      return rows.single['revision'] as int;
    });
    if (revision <= (_revisions[key]?.version ?? 0)) return;
    _revisions[key] = (version: revision, hasImage: image.isNotEmpty);
    notifyListeners();
  }
}

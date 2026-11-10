import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabaseException implements Exception {
  const LocalDatabaseException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'LocalDatabaseException: $message'
      : 'LocalDatabaseException: $message ($cause)';
}

class LocalDatabase {
  LocalDatabase({this.factory, this.databasePath});

  static final LocalDatabase instance = LocalDatabase();

  static const int _version = 5;
  static const String _databaseName = 'pmes_mobile.db';

  final DatabaseFactory? factory;
  final String? databasePath;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    try {
      final databaseFactoryInstance = factory ?? databaseFactory;
      final resolvedPath =
          databasePath ?? path.join(await getDatabasesPath(), _databaseName);

      return await databaseFactoryInstance.openDatabase(
        resolvedPath,
        options: OpenDatabaseOptions(
          version: _version,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE projects (
                id TEXT PRIMARY KEY NOT NULL,
                project_code TEXT,
                contract_ref TEXT,
                title TEXT NOT NULL,
                section TEXT,
                activity TEXT,
                status TEXT,
                publication_status TEXT,
                completion_status TEXT,
                milestone_completion REAL,
                approved_budget TEXT,
                kpis_met TEXT,
                last_synced TEXT,
                latitude TEXT,
                longitude TEXT,
                location_name TEXT,
                location_accuracy REAL
              )
            ''');
            await db.execute('''
              CREATE TABLE progress_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                local_id TEXT NOT NULL UNIQUE,
                project_id TEXT NOT NULL,
                kpis_met TEXT NOT NULL,
                notes TEXT NOT NULL,
                gps_lat REAL,
                gps_lng REAL,
                "timestamp" TEXT NOT NULL,
                is_synced INTEGER NOT NULL DEFAULT 0
                  CHECK (is_synced IN (0, 1)),
                last_sync_attempt_at TEXT,
                last_sync_error TEXT
              )
            ''');
            await db.execute(
              'CREATE INDEX progress_logs_sync_timestamp_idx '
              'ON progress_logs (is_synced, "timestamp")',
            );
            await db.execute(
              'CREATE INDEX progress_logs_project_idx '
              'ON progress_logs (project_id)',
            );
            await db.execute('''
              CREATE TABLE financial_transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                local_id TEXT NOT NULL UNIQUE,
                project_id TEXT NOT NULL,
                objective_id TEXT,
                objective_name TEXT,
                amount REAL NOT NULL,
                transaction_date TEXT NOT NULL,
                remark TEXT NOT NULL,
                "timestamp" TEXT NOT NULL,
                is_synced INTEGER NOT NULL DEFAULT 0
                  CHECK (is_synced IN (0, 1)),
                last_sync_attempt_at TEXT,
                last_sync_error TEXT
              )
            ''');
            await db.execute(
              'CREATE INDEX financial_transactions_sync_timestamp_idx '
              'ON financial_transactions (is_synced, "timestamp")',
            );
            await db.execute(
              'CREATE INDEX financial_transactions_project_idx '
              'ON financial_transactions (project_id)',
            );
            await _createProjectUpdatesTable(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await db.execute(
                'ALTER TABLE progress_logs ADD COLUMN last_sync_attempt_at TEXT',
              );
              await db.execute(
                'ALTER TABLE progress_logs ADD COLUMN last_sync_error TEXT',
              );
            }
            if (oldVersion < 3) {
              await db.execute('''
                CREATE TABLE financial_transactions (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  local_id TEXT NOT NULL UNIQUE,
                  project_id TEXT NOT NULL,
                  objective_id TEXT,
                  amount REAL NOT NULL,
                  transaction_date TEXT NOT NULL,
                  remark TEXT NOT NULL,
                  "timestamp" TEXT NOT NULL,
                  is_synced INTEGER NOT NULL DEFAULT 0
                    CHECK (is_synced IN (0, 1)),
                  last_sync_attempt_at TEXT,
                  last_sync_error TEXT
                )
              ''');
              await db.execute(
                'CREATE INDEX financial_transactions_sync_timestamp_idx '
                'ON financial_transactions (is_synced, "timestamp")',
              );
              await db.execute(
                'CREATE INDEX financial_transactions_project_idx '
                'ON financial_transactions (project_id)',
              );
            }
            if (oldVersion < 4) {
              await _createProjectUpdatesTable(db);
            }
            if (oldVersion < 5) {
              await db.execute(
                'ALTER TABLE financial_transactions '
                'ADD COLUMN objective_name TEXT',
              );
            }
          },
        ),
      );
    } on DatabaseException catch (error) {
      _database = null;
      throw LocalDatabaseException(
        'Unable to open the local database.',
        cause: error,
      );
    }
  }

  static Future<void> _createProjectUpdatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE project_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        project_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        "timestamp" TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
          CHECK (is_synced IN (0, 1)),
        last_sync_attempt_at TEXT,
        last_sync_error TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX project_updates_sync_timestamp_idx '
      'ON project_updates (is_synced, "timestamp")',
    );
    await db.execute(
      'CREATE INDEX project_updates_project_idx '
      'ON project_updates (project_id)',
    );
  }

  Future<void> close() async {
    final pendingDatabase = _database;
    _database = null;
    if (pendingDatabase != null) {
      await (await pendingDatabase).close();
    }
  }
}

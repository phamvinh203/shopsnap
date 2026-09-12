import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../core/constants/app_constants.dart';

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA cache_size = -4000');
      },
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final b = db.batch();
    b.execute(_sqlCategories);
    b.execute(_sqlItems);
    b.execute(_sqlPriceHistory);
    b.execute(_sqlBudgets);
    b.execute(_sqlBudgetAlerts);
    b.execute(_sqlSyncQueue);
    b.execute(_sqlSyncMetadata);
    b.execute(_sqlMigrations);
    _indexes(b);
    _seedCategories(b);
    await b.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int old, int newV) async {
    if (old < 2) await _migrationV2(db);
    if (old < 3) await _migrationV3(db);
  }

  // ─── Migration v2: sync tables ───────────────────────────────────────────
  static Future<void> _migrationV2(Database db) async {
    await db.execute(_sqlSyncQueue);
    await db.execute(_sqlSyncMetadata);
    await db.insert('schema_migrations', {
      'version': 2, 'name': 'add_sync_tables',
      'applied_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ─── Migration v3: sync columns on items ─────────────────────────────────
  static Future<void> _migrationV3(Database db) async {
    await db.execute('ALTER TABLE items ADD COLUMN server_id  TEXT');
    await db.execute('ALTER TABLE items ADD COLUMN is_synced  INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE items ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    await db.execute(_idxItemsUnsynced);
    await db.execute(_idxItemsSoftDelete);
    await db.insert('schema_migrations', {
      'version': 3, 'name': 'add_sync_columns_to_items',
      'applied_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ─── DDL ─────────────────────────────────────────────────────────────────
  static const _sqlCategories = '''
    CREATE TABLE IF NOT EXISTS categories (
      id          TEXT    PRIMARY KEY,
      name        TEXT    NOT NULL,
      icon        TEXT    NOT NULL DEFAULT '🛍️',
      color       TEXT    NOT NULL DEFAULT '#6C63FF',
      is_default  INTEGER NOT NULL DEFAULT 0,
      sort_order  INTEGER NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL
    )''';

  static const _sqlItems = '''
    CREATE TABLE IF NOT EXISTS items (
      id            TEXT    PRIMARY KEY,
      name          TEXT    NOT NULL,
      price         INTEGER NOT NULL DEFAULT 0,
      category_id   TEXT    NOT NULL DEFAULT 'cat_other',
      image_path    TEXT,
      note          TEXT,
      barcode       TEXT,
      latitude      REAL,
      longitude     REAL,
      sticker_data  TEXT,
      created_at    INTEGER NOT NULL,
      updated_at    INTEGER NOT NULL,
      server_id     TEXT,
      is_synced     INTEGER NOT NULL DEFAULT 0,
      is_deleted    INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET DEFAULT
    )''';

  static const _sqlPriceHistory = '''
    CREATE TABLE IF NOT EXISTS price_history (
      id            TEXT    PRIMARY KEY,
      item_name     TEXT    NOT NULL,
      barcode       TEXT,
      price         INTEGER NOT NULL,
      category_id   TEXT,
      purchased_at  INTEGER NOT NULL
    )''';

  static const _sqlBudgets = '''
    CREATE TABLE IF NOT EXISTS budgets (
      id            TEXT    PRIMARY KEY,
      amount        INTEGER NOT NULL,
      period        TEXT    NOT NULL CHECK(period IN ('day','week','month')),
      category_id   TEXT,
      start_date    TEXT    NOT NULL,
      end_date      TEXT    NOT NULL,
      is_active     INTEGER NOT NULL DEFAULT 1,
      created_at    INTEGER NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
    )''';

  static const _sqlBudgetAlerts = '''
    CREATE TABLE IF NOT EXISTS budget_alerts (
      id            TEXT    PRIMARY KEY,
      budget_id     TEXT    NOT NULL,
      percentage    REAL    NOT NULL,
      triggered_at  INTEGER NOT NULL,
      is_dismissed  INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE
    )''';

  static const _sqlSyncQueue = '''
    CREATE TABLE IF NOT EXISTS sync_queue (
      id            TEXT    PRIMARY KEY,
      entity_type   TEXT    NOT NULL,
      entity_id     TEXT    NOT NULL,
      operation     TEXT    NOT NULL CHECK(operation IN ('INSERT','UPDATE','DELETE')),
      payload       TEXT    NOT NULL,
      created_at    INTEGER NOT NULL,
      synced_at     INTEGER,
      retry_count   INTEGER NOT NULL DEFAULT 0,
      error_message TEXT    DEFAULT NULL
    )''';

  static const _sqlSyncMetadata = '''
    CREATE TABLE IF NOT EXISTS sync_metadata (
      key           TEXT    PRIMARY KEY,
      value         TEXT    NOT NULL
    )''';

  static const _sqlMigrations = '''
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version     INTEGER PRIMARY KEY,
      name        TEXT    NOT NULL,
      applied_at  INTEGER NOT NULL
    )''';

  // ─── Indexes ─────────────────────────────────────────────────────────────
  static const _idxItemsUnsynced    = "CREATE INDEX IF NOT EXISTS idx_items_unsynced ON items(is_synced) WHERE is_synced = 0";
  static const _idxItemsSoftDelete  = "CREATE INDEX IF NOT EXISTS idx_items_deleted  ON items(is_deleted) WHERE is_deleted = 0";

  static void _indexes(Batch b) {
    b.execute("CREATE INDEX IF NOT EXISTS idx_items_created_at    ON items(created_at DESC)");
    b.execute("CREATE INDEX IF NOT EXISTS idx_items_category_date ON items(category_id, created_at DESC)");
    b.execute("CREATE INDEX IF NOT EXISTS idx_items_barcode       ON items(barcode) WHERE barcode IS NOT NULL");
    b.execute("CREATE INDEX IF NOT EXISTS idx_ph_item_name        ON price_history(item_name, purchased_at DESC)");
    b.execute("CREATE INDEX IF NOT EXISTS idx_ph_barcode          ON price_history(barcode, purchased_at DESC) WHERE barcode IS NOT NULL");
    b.execute("CREATE INDEX IF NOT EXISTS idx_budgets_active      ON budgets(is_active, period, start_date, end_date)");
    b.execute("CREATE INDEX IF NOT EXISTS idx_alerts_undismissed  ON budget_alerts(budget_id, is_dismissed) WHERE is_dismissed = 0");
    b.execute(_idxItemsUnsynced);
    b.execute(_idxItemsSoftDelete);
  }

  // ─── Seed ─────────────────────────────────────────────────────────────────
  static void _seedCategories(Batch b) {
    final cats = [
      {'id': 'cat_food',     'name': 'Ăn uống',          'icon': '🍜', 'color': '#FF6B6B', 'sort_order': 1},
      {'id': 'cat_clothes',  'name': 'Quần áo',          'icon': '👕', 'color': '#4ECDC4', 'sort_order': 2},
      {'id': 'cat_souvenir', 'name': 'Đồ lưu niệm',      'icon': '🎁', 'color': '#45B7D1', 'sort_order': 3},
      {'id': 'cat_tech',     'name': 'Điện tử',          'icon': '📱', 'color': '#96CEB4', 'sort_order': 4},
      {'id': 'cat_personal', 'name': 'Chăm sóc cá nhân', 'icon': '🧴', 'color': '#FFEAA7', 'sort_order': 5},
      {'id': 'cat_other',    'name': 'Khác',             'icon': '📦', 'color': '#DDA0DD', 'sort_order': 6},
    ];
    for (final c in cats) {
      b.insert('categories', {
        'id': c['id'], 'name': c['name'], 'icon': c['icon'],
        'color': c['color'], 'is_default': 1, 'sort_order': c['sort_order'], 'created_at': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

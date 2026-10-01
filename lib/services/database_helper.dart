import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: _ensureSchema,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        paymentMethod TEXT NOT NULL DEFAULT 'Cash',
        fromSavings INTEGER NOT NULL DEFAULT 0,
        recurringId INTEGER
      )
    ''');
    await _createIncomeTable(db);
    await _createRecurringTable(db);
  }

  Future<void> _createRecurringTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        paymentMethod TEXT NOT NULL DEFAULT 'Cash',
        frequency TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        lastGenerated TEXT,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createIncomeTable(Database db) async {
    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL
      )
    ''');
  }

  /// Runs every time the database opens. Makes sure the Phase 4 pieces exist
  /// even if the version-based upgrade didn't run (e.g. after a partial update).
  Future<void> _ensureSchema(Database db) async {
    await _createRecurringTable(db);
    final cols = await db.rawQuery('PRAGMA table_info(expenses)');
    final hasTag = cols.any((c) => c['name'] == 'recurringId');
    if (!hasTag) {
      await db.execute('ALTER TABLE expenses ADD COLUMN recurringId INTEGER');
    }
  }

  // v1 -> v2: v1 never had the paymentMethod column, even though
  // Expense.toMap() always sends it (which made every insert fail).
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN paymentMethod TEXT NOT NULL DEFAULT 'Cash'",
      );
    }
    // v2 -> v3: added the income table (allowance / money-in tracking).
    if (oldVersion < 3) {
      await _createIncomeTable(db);
    }
    // v3 -> v4: expenses can be paid from savings.
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE expenses ADD COLUMN fromSavings INTEGER NOT NULL DEFAULT 0',
      );
    }
    // v4 -> v5: recurring expenses (+ a tag on expenses they auto-log).
    if (oldVersion < 5) {
      await _createRecurringTable(db);
      await db.execute('ALTER TABLE expenses ADD COLUMN recurringId INTEGER');
    }
  }

  // Insert Expense
  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  // Fetch All Expenses
  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'date DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  // Update Expense (matched by id)
  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Delete Expense
  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Income (allowance / money-in)
  // ---------------------------------------------------------------------------
  Future<int> insertIncome(Income income) async {
    final db = await instance.database;
    return await db.insert('income', income.toMap());
  }

  Future<List<Income>> getAllIncome() async {
    final db = await instance.database;
    final result = await db.query('income', orderBy: 'date DESC');
    return result.map((json) => Income.fromMap(json)).toList();
  }

  Future<int> deleteIncome(int id) async {
    final db = await instance.database;
    return await db.delete('income', where: 'id = ?', whereArgs: [id]);
  }

  // Update Income (matched by id)
  Future<int> updateIncome(Income income) async {
    final db = await instance.database;
    return await db.update(
      'income',
      income.toMap(),
      where: 'id = ?',
      whereArgs: [income.id],
    );
  }

  // ---------------------------------------------------------------------------
  // Recurring expenses
  // ---------------------------------------------------------------------------
  Future<int> insertRecurring(RecurringExpense r) async {
    final db = await instance.database;
    return await db.insert('recurring_expenses', r.toMap());
  }

  Future<List<RecurringExpense>> getAllRecurring() async {
    final db = await instance.database;
    final result = await db.query('recurring_expenses', orderBy: 'id ASC');
    return result.map((json) => RecurringExpense.fromMap(json)).toList();
  }

  Future<int> updateRecurring(RecurringExpense r) async {
    final db = await instance.database;
    return await db.update(
      'recurring_expenses',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<int> deleteRecurring(int id) async {
    final db = await instance.database;
    return await db.delete(
      'recurring_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

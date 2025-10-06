// lib/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// データベースに保存するUsageEventの構造
class UsageEventModel {
  final int? id; // データベース用のID
  final String packageName;
  final String eventType;
  final int timestamp;

  UsageEventModel({this.id, required this.packageName, required this.eventType, required this.timestamp});

  // データベースに保存するためにMap<String, dynamic>に変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'eventType': eventType,
      'timestamp': timestamp,
    };
  }
}

class DatabaseHelper {
  static const _databaseName = "UsageLog.db";
  static const _databaseVersion = 1;
  static const table = 'usage_events';

  // シングルトンクラス（インスタンスが一つしか作られないようにする）
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Databaseインスタンスを保持
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // データベースを初期化する
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path,
        version: _databaseVersion,
        onCreate: _onCreate);
  }

  // データベース作成時にテーブルも作成する
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            packageName TEXT NOT NULL,
            eventType TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
          ''');
  }

  // --- ここからがデータの操作 ---

  // データを挿入する
  Future<int> insert(UsageEventModel event) async {
    Database db = await instance.database;
    return await db.insert(table, event.toMap());
  }

  // 指定した期間の全データを取得する
  Future<List<UsageEventModel>> queryAllEvents(DateTime start, DateTime end) async {
    Database db = await instance.database;
    final maps = await db.query(
      table,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC' // 古い順で取得
    );

    return List.generate(maps.length, (i) {
      return UsageEventModel(
        id: maps[i]['id'] as int,
        packageName: maps[i]['packageName'] as String,
        eventType: maps[i]['eventType'] as String,
        timestamp: maps[i]['timestamp'] as int,
      );
    });
  }
}
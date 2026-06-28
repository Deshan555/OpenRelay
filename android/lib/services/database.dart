import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants.dart';

/// Local SQLite database to cache SMS jobs for history and offline resilience.
class AppDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sms_jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id TEXT NOT NULL,
            recipient TEXT NOT NULL,
            message TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDING',
            created_at TEXT NOT NULL,
            sent_at TEXT
          )
        ''');
      },
    );
  }

  /// Insert a new SMS job received from the server.
  static Future<int> insertJob({
    required String jobId,
    required String recipient,
    required String message,
    String status = 'PENDING',
  }) async {
    final db = await database;
    return await db.insert('sms_jobs', {
      'job_id': jobId,
      'recipient': recipient,
      'message': message,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Update the status of an SMS job.
  static Future<int> updateJobStatus(String jobId, String status) async {
    final db = await database;
    return await db.update(
      'sms_jobs',
      {
        'status': status,
        'sent_at': DateTime.now().toIso8601String(),
      },
      where: 'job_id = ?',
      whereArgs: [jobId],
    );
  }

  /// Get all SMS jobs, newest first.
  static Future<List<Map<String, dynamic>>> getAllJobs() async {
    final db = await database;
    return await db.query('sms_jobs', orderBy: 'created_at DESC');
  }

  /// Get recent SMS jobs (last N).
  static Future<List<Map<String, dynamic>>> getRecentJobs({int limit = 50}) async {
    final db = await database;
    return await db.query('sms_jobs', orderBy: 'created_at DESC', limit: limit);
  }

  /// Get counts by status for dashboard stats.
  static Future<Map<String, int>> getJobStats() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT status, COUNT(*) as count FROM sms_jobs GROUP BY status',
    );
    final stats = <String, int>{};
    for (final row in results) {
      stats[row['status'] as String] = row['count'] as int;
    }
    return stats;
  }

  /// Get count of today's jobs.
  static Future<int> getTodayJobCount() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sms_jobs WHERE created_at LIKE '$today%'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

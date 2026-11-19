import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Item antrean mutasi transaksi lokal untuk mode offline-to-online (`TC-SYNC-03` & `FR-SYNC-04`).
class OfflineTxRecord {
  OfflineTxRecord({
    required this.clientTxId,
    required this.walletId,
    required this.createdBy,
    required this.merchantName,
    required this.category,
    required this.amount,
    required this.source,
    this.receiptUrl,
    required this.txDate,
    required this.updatedAt,
    this.synced = false,
  });

  final String clientTxId;
  final String walletId;
  final String createdBy;
  final String merchantName;
  final String category;
  final int amount;
  final String source;
  final String? receiptUrl;
  final String txDate;
  final DateTime updatedAt;
  bool synced;

  Map<String, dynamic> toSupabasePayload() => {
    'client_tx_id': clientTxId,
    'wallet_id': walletId,
    'created_by': createdBy,
    'merchant_name': merchantName,
    'category': category,
    'amount': amount,
    'source': source,
    if (receiptUrl != null) 'receipt_url': receiptUrl,
    'tx_date': txDate,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toSqliteRow() => {
    'client_tx_id': clientTxId,
    'wallet_id': walletId,
    'created_by': createdBy,
    'merchant_name': merchantName,
    'category': category,
    'amount': amount,
    'source': source,
    'receipt_url': receiptUrl,
    'tx_date': txDate,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  factory OfflineTxRecord.fromSqliteRow(Map<String, dynamic> row) =>
      OfflineTxRecord(
        clientTxId: row['client_tx_id'] as String,
        walletId: row['wallet_id'] as String,
        createdBy: row['created_by'] as String,
        merchantName: row['merchant_name'] as String,
        category: row['category'] as String,
        amount: (row['amount'] as num).toInt(),
        source: row['source'] as String,
        receiptUrl: row['receipt_url'] as String?,
        txDate: row['tx_date'] as String,
        updatedAt: DateTime.parse(row['updated_at'] as String),
        synced: (row['synced'] as int? ?? 0) == 1,
      );
}

/// Mesin sinkronisasi lokal SQLite (`sqflite`) + Supabase PostgreSQL dengan deduplikasi `client_tx_id`
/// dan resolusi konflik Last-Write-Wins berdasarkan `updated_at`.
class OfflineSyncEngine {
  OfflineSyncEngine({SupabaseClient? supabaseClient})
    : _supabase = supabaseClient;

  static const _uuid = Uuid();
  final SupabaseClient? _supabase;
  Database? _db;
  final List<OfflineTxRecord> _memoryQueue = [];
  bool _sqliteUnavailable = false;

  Future<void> _ensureInitialized() async {
    if (_db != null || _sqliteUnavailable) return;
    try {
      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, 'finku_offline_queue.db');
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            create table if not exists offline_tx_queue (
              client_tx_id text primary key,
              wallet_id text not null,
              created_by text not null,
              merchant_name text not null,
              category text not null,
              amount integer not null,
              source text not null,
              receipt_url text,
              tx_date text not null,
              updated_at text not null,
              synced integer not null default 0
            )
          ''');
        },
      );
    } catch (e) {
      debugPrint('SQLite fallback ke antrean memori: $e');
      _sqliteUnavailable = true;
    }
  }

  String generateClientTxId() => _uuid.v4();

  /// Menyimpan mutasi transaksi ke antrean lokal terlebih dahulu (dengan UUID v4 `client_tx_id`).
  /// Jika [isOffline] bernilai `false`, langsung sinkron ke Supabase memakai `upsert(..., onConflict: 'client_tx_id')`.
  Future<OfflineTxRecord> enqueueTransaction({
    String? existingClientTxId,
    required String walletId,
    required String createdBy,
    required String merchantName,
    required String category,
    required int amount,
    required String source,
    String? receiptUrl,
    required String txDate,
    bool isOffline = false,
  }) async {
    await _ensureInitialized();
    final record = OfflineTxRecord(
      clientTxId: existingClientTxId ?? generateClientTxId(),
      walletId: walletId,
      createdBy: createdBy,
      merchantName: merchantName,
      category: category,
      amount: amount,
      source: source,
      receiptUrl: receiptUrl,
      txDate: txDate,
      updatedAt: DateTime.now().toUtc(),
      synced: false,
    );

    if (_db != null) {
      await _db!.insert(
        'offline_tx_queue',
        record.toSqliteRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      _memoryQueue.removeWhere((e) => e.clientTxId == record.clientTxId);
      _memoryQueue.add(record);
    }

    if (!isOffline) {
      await syncPendingToSupabase();
    }
    return record;
  }

  Future<List<OfflineTxRecord>> getPendingRecords() async {
    await _ensureInitialized();
    if (_db != null) {
      final rows = await _db!.query(
        'offline_tx_queue',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'updated_at asc',
      );
      return rows.map(OfflineTxRecord.fromSqliteRow).toList();
    }
    return _memoryQueue.where((e) => !e.synced).toList();
  }

  Future<int> getPendingCount() async {
    final pending = await getPendingRecords();
    return pending.length;
  }

  /// Menyinkronkan seluruh antrean tertunda ke Supabase menggunakan strategi Last-Write-Wins.
  Future<int> syncPendingToSupabase() async {
    await _ensureInitialized();
    final pending = await getPendingRecords();
    if (pending.isEmpty) return 0;

    final client = _supabase;
    if (client == null) return 0;

    var syncedCount = 0;
    for (final item in pending) {
      try {
        // Cek apakah baris dengan client_tx_id sudah ada dan bandingkan updated_at (Last-Write-Wins)
        final existing = await client
            .from('transactions')
            .select('updated_at')
            .eq('client_tx_id', item.clientTxId)
            .maybeSingle();

        var shouldWrite = true;
        if (existing != null && existing['updated_at'] != null) {
          final remoteUpdated = DateTime.tryParse(existing['updated_at'] as String);
          if (remoteUpdated != null && remoteUpdated.isAfter(item.updatedAt)) {
            shouldWrite = false;
          }
        }

        if (shouldWrite) {
          await client
              .from('transactions')
              .upsert(item.toSupabasePayload(), onConflict: 'client_tx_id');
        }

        await _markSynced(item.clientTxId);
        syncedCount++;
      } catch (e) {
        debugPrint('Gagal sync item ${item.clientTxId}: $e');
      }
    }
    return syncedCount;
  }

  Future<void> _markSynced(String clientTxId) async {
    if (_db != null) {
      await _db!.update(
        'offline_tx_queue',
        {'synced': 1},
        where: 'client_tx_id = ?',
        whereArgs: [clientTxId],
      );
    } else {
      for (final item in _memoryQueue) {
        if (item.clientTxId == clientTxId) {
          item.synced = true;
        }
      }
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/category_taxonomy.dart';
import '../../../core/sync/offline_sync_engine.dart';
import '../domain/models/wallet_models.dart';

class PermissionDeniedException implements Exception {
  const PermissionDeniedException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Repositori terpusat dompet pribadi, dompet bersama, anggaran, dan transaksi
/// yang terhubung penuh ke Supabase PostgreSQL & Realtime Streams (`FR-SYNC-01..04`).
class WalletRepository {
  WalletRepository({
    SupabaseClient? supabaseClient,
    OfflineSyncEngine? offlineSyncEngine,
  }) : _supabase = supabaseClient,
       _syncEngine =
           offlineSyncEngine ?? OfflineSyncEngine(supabaseClient: supabaseClient);

  final SupabaseClient? _supabase;
  final OfflineSyncEngine _syncEngine;
  static const _uuid = Uuid();

  OfflineSyncEngine get syncEngine => _syncEngine;

  bool get _hasActiveSupabaseSession =>
      _supabase != null && _supabase.auth.currentSession != null;

  /// Mengambil seluruh dompet yang dimiliki atau diikuti user (Mode Biasa + Mode Bersama)
  /// beserta peran RBAC per-dompet dari `wallet_members`.
  Future<List<WalletInfo>> fetchUserWallets(String userId) async {
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        final rows = await client
            .from('wallet_members')
            .select('role, wallets(id, name, is_shared, invite_code, created_by)')
            .eq('user_id', userId);

        final wallets = <WalletInfo>[];
        for (final r in (rows as List)) {
          final map = Map<String, dynamic>.from(r as Map);
          final wRaw = map['wallets'];
          if (wRaw is Map) {
            final w = Map<String, dynamic>.from(wRaw);
            wallets.add(
              WalletInfo(
                id: w['id'].toString(),
                name: w['name']?.toString() ?? 'Dompet',
                isShared: (w['is_shared'] as bool?) ?? false,
                role: map['role']?.toString() ?? 'viewer',
                inviteCode: w['invite_code']?.toString(),
                createdBy: w['created_by']?.toString() ?? '',
              ),
            );
          }
        }
        if (wallets.isNotEmpty) {
          wallets.sort((a, b) {
            if (a.isShared != b.isShared) return a.isShared ? 1 : -1;
            return a.name.compareTo(b.name);
          });
          return wallets;
        }
      } catch (e) {
        debugPrint('fetchUserWallets fallback ke seed: $e');
      }
    }

    return seededWalletsForUser(userId);
  }

  /// Membuat Dompet Bersama baru (`is_shared = true`, pembuat otomatis `owner`).
  Future<WalletInfo> createSharedWallet({
    required String name,
    required String userId,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Nama dompet bersama wajib diisi.');
    }

    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      final walletId = await client.rpc(
        'create_shared_wallet',
        params: {'p_name': cleanName},
      );
      final idStr = walletId.toString();
      final row = await client
          .from('wallets')
          .select('id, name, is_shared, invite_code, created_by')
          .eq('id', idStr)
          .single();
      return WalletInfo(
        id: row['id'].toString(),
        name: row['name']?.toString() ?? cleanName,
        isShared: true,
        role: 'owner',
        inviteCode: row['invite_code']?.toString(),
        createdBy: row['created_by']?.toString() ?? userId,
      );
    }

    final code = 'FNK-${_uuid.v4().substring(0, 6).toUpperCase()}';
    return WalletInfo(
      id: _uuid.v4(),
      name: cleanName,
      isShared: true,
      role: 'owner',
      inviteCode: code,
      createdBy: userId,
    );
  }

  /// Bergabung ke Dompet Bersama melalui kode undangan (`join_wallet_by_invite`).
  Future<String> joinSharedWalletByCode({required String inviteCode}) async {
    final cleanCode = inviteCode.trim();
    if (cleanCode.isEmpty) {
      throw const FormatException('Kode undangan wajib diisi.');
    }

    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      final walletId = await client.rpc(
        'join_wallet_by_invite',
        params: {'p_invite_code': cleanCode},
      );
      return walletId.toString();
    }

    if (cleanCode.toUpperCase() == 'KOS-2026-FNK') {
      return SupabaseConfig.sharedWalletId;
    }
    throw Exception('Kode undangan tidak ditemukan.');
  }

  /// Mengambil daftar anggota dompet beserta peran RBAC & avatar dari Supabase.
  Future<List<WalletMemberInfo>> fetchWalletMembers(
    String walletId, {
    String? currentUserId,
    String? currentUserName,
    String? currentUserEmail,
    String? currentUserInitials,
    String? currentUserAvatarUrl,
  }) async {
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        final rows = await client
            .from('wallet_members')
            .select('wallet_id, user_id, role')
            .eq('wallet_id', walletId);

        final userIds =
            (rows as List).map((r) => r['user_id'].toString()).toList();
        final profileRows = userIds.isEmpty
            ? <dynamic>[]
            : await client
                .from('profiles')
                .select('id, email, full_name, avatar_initials, avatar_url')
                .inFilter('id', userIds);

        final profilesById = <String, Map<String, dynamic>>{};
        for (final p in profileRows) {
          final map = Map<String, dynamic>.from(p as Map);
          profilesById[map['id'].toString()] = map;
        }

        final result = <WalletMemberInfo>[];
        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final uid = map['user_id'].toString();
          final prof = profilesById[uid];
          result.add(
            WalletMemberInfo(
              walletId: map['wallet_id'].toString(),
              userId: uid,
              fullName: prof?['full_name']?.toString() ?? 'Anggota',
              email: prof?['email']?.toString() ?? '',
              avatarInitials: prof?['avatar_initials']?.toString() ?? 'FK',
              avatarUrl: prof?['avatar_url']?.toString(),
              role: map['role']?.toString() ?? 'viewer',
            ),
          );
        }
        if (result.isNotEmpty) return result;
      } catch (e) {
        debugPrint('fetchWalletMembers fallback ke seed: $e');
      }
    }

    if (walletId == SupabaseConfig.personalWalletId ||
        walletId == SupabaseConfig.sharedWalletId) {
      return seededMembers(walletId);
    }
    return [
      WalletMemberInfo(
        walletId: walletId,
        userId: currentUserId ?? SupabaseConfig.demoOwnerId,
        fullName: currentUserName ?? 'Pemilik Dompet',
        email: currentUserEmail ?? '',
        avatarInitials: currentUserInitials ?? 'FK',
        avatarUrl: currentUserAvatarUrl,
        role: 'owner',
      ),
    ];
  }

  /// Mengubah hak akses anggota (`editor` <-> `viewer`) oleh Owner Dompet Bersama.
  Future<void> updateMemberRole({
    required String walletId,
    required String targetUserId,
    required String newRole,
    required String activeUserRole,
  }) async {
    if (activeUserRole != 'owner') {
      throw const PermissionDeniedException(
        'Permission denied: Hanya Owner dompet bersama yang dapat mengubah hak akses anggota.',
      );
    }
    if (newRole != 'editor' && newRole != 'viewer') {
      throw ArgumentError('Role tidak valid: $newRole');
    }

    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      await client
          .from('wallet_members')
          .update({'role': newRole})
          .eq('wallet_id', walletId)
          .eq('user_id', targetUserId);
    }
  }

  /// Mengeluarkan anggota dari Dompet Bersama oleh Owner.
  Future<void> removeMember({
    required String walletId,
    required String targetUserId,
    required String activeUserRole,
  }) async {
    if (activeUserRole != 'owner') {
      throw const PermissionDeniedException(
        'Permission denied: Hanya Owner dompet bersama yang dapat mengeluarkan anggota.',
      );
    }

    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      await client
          .from('wallet_members')
          .delete()
          .eq('wallet_id', walletId)
          .eq('user_id', targetUserId);
    }
  }

  /// Menentukan peran pengguna aktif pada suatu dompet.
  Future<String> fetchUserRoleForWallet({
    required String walletId,
    required String userId,
    required String fallbackRole,
  }) async {
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        final row = await client
            .from('wallet_members')
            .select('role')
            .eq('wallet_id', walletId)
            .eq('user_id', userId)
            .maybeSingle();
        if (row != null && row['role'] != null) {
          return row['role'].toString();
        }
      } catch (_) {}
    }
    if (walletId == SupabaseConfig.sharedWalletId) {
      if (userId == SupabaseConfig.demoViewerId) return 'viewer';
      if (userId == SupabaseConfig.demoEditorId) return 'editor';
      if (userId == SupabaseConfig.demoOwnerId) return 'owner';
    }
    return fallbackRole;
  }

  /// Mengambil daftar transaksi dari Supabase `public.transactions`.
  Future<List<TransactionItem>> fetchTransactions(
    String walletId, {
    Map<String, WalletMemberInfo> membersByUserId = const {},
  }) async {
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        final rows = await client
            .from('transactions')
            .select()
            .eq('wallet_id', walletId)
            .order('tx_date', ascending: false)
            .order('created_at', ascending: false);
        return (rows as List)
            .map(
              (r) => TransactionItem.fromSupabaseMap(
                Map<String, dynamic>.from(r as Map),
                membersByUserId: membersByUserId,
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('fetchTransactions fallback: $e');
      }
    }
    if (walletId == SupabaseConfig.personalWalletId ||
        walletId == SupabaseConfig.sharedWalletId) {
      return seededTransactions(walletId);
    }
    return const [];
  }

  /// Stream real-time Supabase (`< 1.5 detik`) dengan kunci primer `['id']` dan filter `wallet_id`.
  Stream<List<TransactionItem>> watchTransactions(
    String walletId, {
    Map<String, WalletMemberInfo> membersByUserId = const {},
  }) {
    final client = _supabase;
    if (client == null || client.auth.currentSession == null) {
      if (walletId == SupabaseConfig.personalWalletId ||
          walletId == SupabaseConfig.sharedWalletId) {
        return Stream.value(seededTransactions(walletId));
      }
      return Stream.value(const []);
    }

    return client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('wallet_id', walletId)
        .order('tx_date', ascending: false)
        .map(
          (rows) => rows
              .map(
                (r) => TransactionItem.fromSupabaseMap(
                  r,
                  membersByUserId: membersByUserId,
                ),
              )
              .toList(),
        );
  }

  /// Mengambil anggaran bulanan dari Supabase `public.budgets`.
  Future<List<BudgetItem>> fetchBudgets(String walletId) async {
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        final rows = await client
            .from('budgets')
            .select()
            .eq('wallet_id', walletId);
        return (rows as List)
            .map(
              (r) => BudgetItem.fromSupabaseMap(
                Map<String, dynamic>.from(r as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('fetchBudgets fallback: $e');
      }
    }
    if (walletId == SupabaseConfig.personalWalletId ||
        walletId == SupabaseConfig.sharedWalletId) {
      return seededBudgets(walletId);
    }
    return const [];
  }

  /// Stream real-time Supabase untuk `public.budgets`.
  Stream<List<BudgetItem>> watchBudgets(String walletId) {
    final client = _supabase;
    if (client == null || client.auth.currentSession == null) {
      if (walletId == SupabaseConfig.personalWalletId ||
          walletId == SupabaseConfig.sharedWalletId) {
        return Stream.value(seededBudgets(walletId));
      }
      return Stream.value(const []);
    }
    return client
        .from('budgets')
        .stream(primaryKey: ['id'])
        .eq('wallet_id', walletId)
        .map((rows) => rows.map(BudgetItem.fromSupabaseMap).toList());
  }

  bool get isLiveSession => _hasActiveSupabaseSession;

  /// Menambah transaksi melalui `OfflineSyncEngine` (UUID v4 `client_tx_id` & upsert LWW).
  Future<TransactionItem> addTransaction({
    required String walletId,
    required String userId,
    required String userName,
    required String userRole,
    required String merchantName,
    required String category,
    required int amount,
    required String source,
    DateTime? txDate,
    String? receiptUrl,
    bool isOffline = false,
  }) async {
    if (userRole == 'viewer') {
      throw const PermissionDeniedException(
        'Permission denied: Peran Viewer tidak diizinkan mencatat transaksi.',
      );
    }

    final normalizedCat = CategoryTaxonomy.normalize(category);
    final date = txDate ?? DateTime(2026, 11, 18);
    final isoDate =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final record = await _syncEngine.enqueueTransaction(
      walletId: walletId,
      createdBy: userId,
      merchantName: merchantName,
      category: normalizedCat,
      amount: amount,
      source: source,
      receiptUrl: receiptUrl,
      txDate: isoDate,
      isOffline: isOffline,
    );

    return TransactionItem(
      id: record.clientTxId,
      clientTxId: record.clientTxId,
      walletId: walletId,
      createdBy: userId,
      authorName: userName,
      authorRole: userRole,
      merchantName: merchantName,
      category: normalizedCat,
      amount: amount,
      source: source,
      receiptUrl: receiptUrl,
      txDate: date,
      createdAt: record.updatedAt,
      updatedAt: record.updatedAt,
      isPendingSync: isOffline,
    );
  }

  /// Memperbarui transaksi (hanya `owner` & `editor`, ditolak keras untuk `viewer` di UI & RLS).
  Future<void> updateTransaction({
    required TransactionItem tx,
    required String activeUserRole,
    required String newMerchantName,
    required String newCategory,
    required int newAmount,
  }) async {
    if (activeUserRole == 'viewer') {
      throw const PermissionDeniedException(
        'Permission denied: Peran Viewer hanya memiliki akses lihat (Read-only).',
      );
    }
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      await client
          .from('transactions')
          .update({
            'merchant_name': newMerchantName,
            'category': CategoryTaxonomy.normalize(newCategory),
            'amount': newAmount,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('client_tx_id', tx.clientTxId);
    }
  }

  /// Menghapus transaksi (hanya `owner` & `editor`).
  Future<void> deleteTransaction({
    required TransactionItem tx,
    required String activeUserRole,
  }) async {
    if (activeUserRole == 'viewer') {
      throw const PermissionDeniedException(
        'Permission denied: Peran Viewer tidak dapat menghapus transaksi.',
      );
    }
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      await client
          .from('transactions')
          .delete()
          .eq('client_tx_id', tx.clientTxId);
    }
  }

  /// Menyimpan batas anggaran bulanan ke `public.budgets` (`TC-VIS-02`).
  Future<void> upsertBudgetLimit({
    required String walletId,
    required String activeUserRole,
    required String category,
    required String monthPeriod,
    required int limitAmount,
  }) async {
    if (activeUserRole == 'viewer') {
      throw const PermissionDeniedException(
        'Permission denied: Peran Viewer tidak dapat mengubah batas anggaran.',
      );
    }
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      await client.from('budgets').upsert({
        'wallet_id': walletId,
        'category': CategoryTaxonomy.normalize(category),
        'month_period': monthPeriod,
        'limit_amount': limitAmount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'wallet_id,category,month_period');
    }
  }

  static List<WalletInfo> seededWalletsForUser(String userId) {
    final sharedRole = userId == SupabaseConfig.demoViewerId
        ? 'viewer'
        : (userId == SupabaseConfig.demoEditorId ? 'editor' : 'owner');
    return [
      WalletInfo(
        id: SupabaseConfig.personalWalletId,
        name: 'Dompet Pribadi',
        isShared: false,
        role: 'owner',
        createdBy: userId,
      ),
      WalletInfo(
        id: SupabaseConfig.sharedWalletId,
        name: 'Anggaran Rumah Tangga & Kos',
        isShared: true,
        role: sharedRole,
        inviteCode: 'KOS-2026-FNK',
        createdBy: SupabaseConfig.demoOwnerId,
      ),
    ];
  }

  static List<WalletMemberInfo> seededMembers(String walletId) {
    if (walletId == SupabaseConfig.personalWalletId) {
      return const [
        WalletMemberInfo(
          walletId: SupabaseConfig.personalWalletId,
          userId: SupabaseConfig.demoOwnerId,
          fullName: SupabaseConfig.demoOwnerName,
          email: SupabaseConfig.demoOwnerEmail,
          avatarInitials: 'BS',
          role: 'owner',
        ),
      ];
    }
    return const [
      WalletMemberInfo(
        walletId: SupabaseConfig.sharedWalletId,
        userId: SupabaseConfig.demoOwnerId,
        fullName: SupabaseConfig.demoOwnerName,
        email: SupabaseConfig.demoOwnerEmail,
        avatarInitials: 'BS',
        role: 'owner',
      ),
      WalletMemberInfo(
        walletId: SupabaseConfig.sharedWalletId,
        userId: SupabaseConfig.demoEditorId,
        fullName: SupabaseConfig.demoEditorName,
        email: SupabaseConfig.demoEditorEmail,
        avatarInitials: 'SD',
        role: 'editor',
      ),
      WalletMemberInfo(
        walletId: SupabaseConfig.sharedWalletId,
        userId: SupabaseConfig.demoViewerId,
        fullName: SupabaseConfig.demoViewerName,
        email: SupabaseConfig.demoViewerEmail,
        avatarInitials: 'RP',
        role: 'viewer',
      ),
    ];
  }

  static List<BudgetItem> seededBudgets(String walletId) {
    final now = DateTime(2026, 11, 1);
    if (walletId == SupabaseConfig.sharedWalletId) {
      return [
        BudgetItem(
          id: 'b-shared-1',
          walletId: walletId,
          category: CategoryTaxonomy.belanjaHarian,
          monthPeriod: '2026-11',
          limitAmount: 3000000,
          updatedAt: now,
        ),
        BudgetItem(
          id: 'b-shared-2',
          walletId: walletId,
          category: CategoryTaxonomy.tagihanUtilitas,
          monthPeriod: '2026-11',
          limitAmount: 2500000,
          updatedAt: now,
        ),
        BudgetItem(
          id: 'b-shared-3',
          walletId: walletId,
          category: CategoryTaxonomy.makananMinuman,
          monthPeriod: '2026-11',
          limitAmount: 2500000,
          updatedAt: now,
        ),
        BudgetItem(
          id: 'b-shared-4',
          walletId: walletId,
          category: CategoryTaxonomy.transportasi,
          monthPeriod: '2026-11',
          limitAmount: 1000000,
          updatedAt: now,
        ),
        BudgetItem(
          id: 'b-shared-5',
          walletId: walletId,
          category: CategoryTaxonomy.lainnya,
          monthPeriod: '2026-11',
          limitAmount: 1000000,
          updatedAt: now,
        ),
      ];
    }

    return [
      BudgetItem(
        id: 'b-personal-1',
        walletId: walletId,
        category: CategoryTaxonomy.makananMinuman,
        monthPeriod: '2026-11',
        limitAmount: 1000000,
        updatedAt: now,
      ),
      BudgetItem(
        id: 'b-personal-2',
        walletId: walletId,
        category: CategoryTaxonomy.transportasi,
        monthPeriod: '2026-11',
        limitAmount: 500000,
        updatedAt: now,
      ),
      BudgetItem(
        id: 'b-personal-3',
        walletId: walletId,
        category: CategoryTaxonomy.hiburanGayaHidup,
        monthPeriod: '2026-11',
        limitAmount: 500000,
        updatedAt: now,
      ),
      BudgetItem(
        id: 'b-personal-4',
        walletId: walletId,
        category: CategoryTaxonomy.belanjaHarian,
        monthPeriod: '2026-11',
        limitAmount: 1500000,
        updatedAt: now,
      ),
      BudgetItem(
        id: 'b-personal-5',
        walletId: walletId,
        category: CategoryTaxonomy.tagihanUtilitas,
        monthPeriod: '2026-11',
        limitAmount: 1000000,
        updatedAt: now,
      ),
    ];
  }

  static List<TransactionItem> seededTransactions(String walletId) {
    if (walletId == SupabaseConfig.sharedWalletId) {
      return [
        TransactionItem(
          id: 'seed-shared-01',
          clientTxId: 'seed-shared-01',
          walletId: walletId,
          createdBy: SupabaseConfig.demoEditorId,
          authorName: 'Sinta Dewi',
          authorRole: 'editor',
          merchantName: 'Superindo - Belanja Bulanan Kos',
          category: CategoryTaxonomy.belanjaHarian,
          amount: 450000,
          source: 'ocr',
          txDate: DateTime(2026, 11, 18, 14, 20),
          createdAt: DateTime(2026, 11, 18, 14, 20),
          updatedAt: DateTime(2026, 11, 18, 14, 20),
        ),
        TransactionItem(
          id: 'seed-shared-02',
          clientTxId: 'seed-shared-02',
          walletId: walletId,
          createdBy: SupabaseConfig.demoOwnerId,
          authorName: 'Budi Santoso',
          authorRole: 'owner',
          merchantName: 'Token Listrik PLN 200k',
          category: CategoryTaxonomy.tagihanUtilitas,
          amount: 202500,
          source: 'manual',
          txDate: DateTime(2026, 11, 18, 9, 15),
          createdAt: DateTime(2026, 11, 18, 9, 15),
          updatedAt: DateTime(2026, 11, 18, 9, 15),
        ),
        TransactionItem(
          id: 'seed-shared-03',
          clientTxId: 'seed-shared-03',
          walletId: walletId,
          createdBy: SupabaseConfig.demoEditorId,
          authorName: 'Sinta Dewi',
          authorRole: 'editor',
          merchantName: 'Air Galon & Gas LPG',
          category: CategoryTaxonomy.belanjaHarian,
          amount: 85000,
          source: 'ai_chat',
          txDate: DateTime(2026, 11, 17, 16, 40),
          createdAt: DateTime(2026, 11, 17, 16, 40),
          updatedAt: DateTime(2026, 11, 17, 16, 40),
        ),
      ];
    }

    return [
      TransactionItem(
        id: 'seed-personal-01',
        clientTxId: 'seed-personal-01',
        walletId: walletId,
        createdBy: SupabaseConfig.demoOwnerId,
        authorName: 'Budi Santoso',
        authorRole: 'owner',
        merchantName: 'Warteg Bahari & Kopi Kenangan',
        category: CategoryTaxonomy.makananMinuman,
        amount: 720000,
        source: 'manual',
        txDate: DateTime(2026, 11, 4),
        createdAt: DateTime(2026, 11, 4),
        updatedAt: DateTime(2026, 11, 4),
      ),
      TransactionItem(
        id: 'seed-personal-02',
        clientTxId: 'seed-personal-02',
        walletId: walletId,
        createdBy: SupabaseConfig.demoOwnerId,
        authorName: 'Budi Santoso',
        authorRole: 'owner',
        merchantName: 'Pertamina Pertamax & GoRide',
        category: CategoryTaxonomy.transportasi,
        amount: 425000,
        source: 'ai_chat',
        txDate: DateTime(2026, 11, 9),
        createdAt: DateTime(2026, 11, 9),
        updatedAt: DateTime(2026, 11, 9),
      ),
      TransactionItem(
        id: 'seed-personal-03',
        clientTxId: 'seed-personal-03',
        walletId: walletId,
        createdBy: SupabaseConfig.demoOwnerId,
        authorName: 'Budi Santoso',
        authorRole: 'owner',
        merchantName: 'Bioskop XXI & Konser Musik',
        category: CategoryTaxonomy.hiburanGayaHidup,
        amount: 550000,
        source: 'manual',
        txDate: DateTime(2026, 11, 12),
        createdAt: DateTime(2026, 11, 12),
        updatedAt: DateTime(2026, 11, 12),
      ),
      TransactionItem(
        id: 'seed-personal-04',
        clientTxId: 'seed-personal-04',
        walletId: walletId,
        createdBy: SupabaseConfig.demoOwnerId,
        authorName: 'Budi Santoso',
        authorRole: 'owner',
        merchantName: 'Indomaret Mingguan',
        category: CategoryTaxonomy.belanjaHarian,
        amount: 450000,
        source: 'ocr',
        txDate: DateTime(2026, 11, 14),
        createdAt: DateTime(2026, 11, 14),
        updatedAt: DateTime(2026, 11, 14),
      ),
      TransactionItem(
        id: 'seed-personal-05',
        clientTxId: 'seed-personal-05',
        walletId: walletId,
        createdBy: SupabaseConfig.demoOwnerId,
        authorName: 'Budi Santoso',
        authorRole: 'owner',
        merchantName: 'Superindo Bulanan',
        category: CategoryTaxonomy.belanjaHarian,
        amount: 500000,
        source: 'ocr',
        txDate: DateTime(2026, 11, 16),
        createdAt: DateTime(2026, 11, 16),
        updatedAt: DateTime(2026, 11, 16),
      ),
      TransactionItem(
        id: 'seed-personal-06',
        clientTxId: 'seed-personal-06',
        walletId: walletId,
        createdBy: SupabaseConfig.demoOwnerId,
        authorName: 'Budi Santoso',
        authorRole: 'owner',
        merchantName: 'PLN Pascabayar & IndiHome',
        category: CategoryTaxonomy.tagihanUtilitas,
        amount: 805000,
        source: 'manual',
        txDate: DateTime(2026, 11, 18),
        createdAt: DateTime(2026, 11, 18),
        updatedAt: DateTime(2026, 11, 18),
      ),
    ];
  }
}

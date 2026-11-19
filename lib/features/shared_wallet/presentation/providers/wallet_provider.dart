import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finku_app/core/config/supabase_config.dart';
import 'package:finku_app/core/constants/category_taxonomy.dart';
import 'package:finku_app/features/auth/domain/entities/app_user.dart';
import 'package:finku_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:finku_app/features/budget_analytics/domain/models/budget_summary.dart';
import 'package:finku_app/features/shared_wallet/data/wallet_repository.dart';
import 'package:finku_app/features/shared_wallet/domain/models/wallet_models.dart';

class WalletState {
  const WalletState({
    required this.activeWalletId,
    required this.isSharedWallet,
    required this.selectedMonth,
    required this.availableWallets,
    required this.transactions,
    required this.budgets,
    required this.members,
    required this.activeRole,
    this.isOfflineMode = false,
    this.pendingSyncCount = 0,
    this.isSyncing = false,
    this.lastSyncLatencyMs = 240,
  });

  final String activeWalletId;
  final bool isSharedWallet;
  final String selectedMonth;
  final List<WalletInfo> availableWallets;
  final List<TransactionItem> transactions;
  final List<BudgetItem> budgets;
  final List<WalletMemberInfo> members;
  final String activeRole; // 'owner' | 'editor' | 'viewer'
  final bool isOfflineMode;
  final int pendingSyncCount;
  final bool isSyncing;
  final int lastSyncLatencyMs;

  bool get canEdit => activeRole == 'owner' || activeRole == 'editor';
  bool get isOwner => activeRole == 'owner';

  WalletInfo? get activeWallet {
    for (final w in availableWallets) {
      if (w.id == activeWalletId) return w;
    }
    return null;
  }

  List<WalletInfo> get personalWallets =>
      availableWallets.where((w) => !w.isShared).toList();

  List<WalletInfo> get sharedWallets =>
      availableWallets.where((w) => w.isShared).toList();

  String get walletTitle =>
      activeWallet?.name ??
      (isSharedWallet ? 'Anggaran Rumah Tangga & Kos' : 'Dompet Pribadi');

  String? get activeInviteCode =>
      activeWallet?.inviteCode ?? (isSharedWallet ? 'KOS-2026-FNK' : null);

  int get sharedWalletBalance {
    final totalSpend = transactions.fold<int>(0, (acc, tx) => acc + tx.amount);
    return 8987500 - totalSpend;
  }

  BudgetSummary get summary => BudgetSummary.compute(
    transactions: transactions,
    budgets: budgets,
    monthPeriod: selectedMonth,
  );

  WalletState copyWith({
    String? activeWalletId,
    bool? isSharedWallet,
    String? selectedMonth,
    List<WalletInfo>? availableWallets,
    List<TransactionItem>? transactions,
    List<BudgetItem>? budgets,
    List<WalletMemberInfo>? members,
    String? activeRole,
    bool? isOfflineMode,
    int? pendingSyncCount,
    bool? isSyncing,
    int? lastSyncLatencyMs,
  }) {
    return WalletState(
      activeWalletId: activeWalletId ?? this.activeWalletId,
      isSharedWallet: isSharedWallet ?? this.isSharedWallet,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      availableWallets: availableWallets ?? this.availableWallets,
      transactions: transactions ?? this.transactions,
      budgets: budgets ?? this.budgets,
      members: members ?? this.members,
      activeRole: activeRole ?? this.activeRole,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncLatencyMs: lastSyncLatencyMs ?? this.lastSyncLatencyMs,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier({
    required WalletRepository repository,
    required AppUser? currentUser,
  }) : _repo = repository,
       _user = currentUser,
       super(
         WalletState(
           activeWalletId: SupabaseConfig.personalWalletId,
           isSharedWallet: false,
           selectedMonth: '2026-11',
           availableWallets: WalletRepository.seededWalletsForUser(
             currentUser?.id ?? SupabaseConfig.demoOwnerId,
           ),
           transactions: WalletRepository.seededTransactions(
             SupabaseConfig.personalWalletId,
           ),
           budgets: WalletRepository.seededBudgets(
             SupabaseConfig.personalWalletId,
           ),
           members: WalletRepository.seededMembers(
             SupabaseConfig.personalWalletId,
           ),
           activeRole: 'owner',
         ),
       ) {
    _initializeWalletsAndSubscribe();
  }

  final WalletRepository _repo;
  final AppUser? _user;
  StreamSubscription<List<TransactionItem>>? _txSub;
  StreamSubscription<List<BudgetItem>>? _budgetSub;
  bool _hasUserSwitchedWallet = false;

  @override
  void dispose() {
    _txSub?.cancel();
    _budgetSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeWalletsAndSubscribe() async {
    final user = _user;
    if (user != null) {
      final wallets = await _repo.fetchUserWallets(user.id);
      if (!mounted) return;
      if (_hasUserSwitchedWallet) {
        if (wallets.isNotEmpty) {
          state = state.copyWith(availableWallets: wallets);
        }
        return;
      }
      if (wallets.isNotEmpty) {
        final personal = wallets.where((w) => !w.isShared).toList();
        final chosen = personal.isNotEmpty ? personal.first : wallets.first;
        state = state.copyWith(
          availableWallets: wallets,
          activeWalletId: chosen.id,
          isSharedWallet: chosen.isShared,
          activeRole: chosen.role,
        );
      }
    }
    if (_hasUserSwitchedWallet) return;
    await _loadAndSubscribe();
  }

  Future<void> refreshWallets({String? selectWalletId}) async {
    final user = _user;
    if (user == null) return;
    final wallets = await _repo.fetchUserWallets(user.id);
    if (!mounted) return;

    final targetId = selectWalletId ?? state.activeWalletId;
    WalletInfo? target;
    for (final w in wallets) {
      if (w.id == targetId) {
        target = w;
        break;
      }
    }
    target ??= wallets.isNotEmpty ? wallets.first : null;

    state = state.copyWith(
      availableWallets: wallets,
      activeWalletId: target?.id ?? state.activeWalletId,
      isSharedWallet: target?.isShared ?? state.isSharedWallet,
      activeRole: target?.role ?? state.activeRole,
    );
    await _loadAndSubscribe();
  }

  Future<void> _loadAndSubscribe() async {
    await _txSub?.cancel();
    await _budgetSub?.cancel();

    final walletId = state.activeWalletId;
    final user = _user;

    final members = await _repo.fetchWalletMembers(
      walletId,
      currentUserId: user?.id,
      currentUserName: user?.fullName,
      currentUserEmail: user?.email,
      currentUserInitials: user?.avatarInitials,
      currentUserAvatarUrl: user?.avatarUrl,
    );
    final membersMap = {for (final m in members) m.userId: m};

    final fallbackRole =
        state.activeWallet?.role ?? (state.isSharedWallet ? 'viewer' : 'owner');
    final role = user == null
        ? 'owner'
        : await _repo.fetchUserRoleForWallet(
            walletId: walletId,
            userId: user.id,
            fallbackRole: fallbackRole,
          );

    if (!mounted) return;
    state = state.copyWith(members: members, activeRole: role);

    final stopwatch = Stopwatch()..start();
    final initialTxs = await _repo.fetchTransactions(
      walletId,
      membersByUserId: membersMap,
    );
    final initialBudgets = await _repo.fetchBudgets(walletId);
    stopwatch.stop();

    if (!mounted) return;
    state = state.copyWith(
      transactions: initialTxs,
      budgets: initialBudgets,
      lastSyncLatencyMs: stopwatch.elapsedMilliseconds,
    );

    // Langganan real-time Supabase (`FR-SYNC-03`)
    _txSub = _repo
        .watchTransactions(walletId, membersByUserId: membersMap)
        .listen(
          (txs) {
            if (!mounted || state.isOfflineMode) return;
            if (_repo.isLiveSession || txs.isNotEmpty) {
              state = state.copyWith(
                transactions: txs,
                lastSyncLatencyMs: 180,
              );
            }
          },
          onError: (Object e) {
            debugPrint('Realtime tx stream notice: $e');
          },
        );

    _budgetSub = _repo.watchBudgets(walletId).listen(
      (budgets) {
        if (!mounted || state.isOfflineMode) return;
        if (_repo.isLiveSession || budgets.isNotEmpty) {
          state = state.copyWith(budgets: budgets);
        }
      },
      onError: (Object e) {
        debugPrint('Realtime budget stream notice: $e');
      },
    );
  }

  Future<void> selectWallet(String walletId) async {
    _hasUserSwitchedWallet = true;
    if (state.activeWalletId == walletId) return;
    WalletInfo? target;
    for (final w in state.availableWallets) {
      if (w.id == walletId) {
        target = w;
        break;
      }
    }
    if (target == null) return;

    state = state.copyWith(
      activeWalletId: target.id,
      isSharedWallet: target.isShared,
      activeRole: target.role,
      transactions: (target.id == SupabaseConfig.personalWalletId ||
              target.id == SupabaseConfig.sharedWalletId)
          ? WalletRepository.seededTransactions(target.id)
          : const [],
      budgets: (target.id == SupabaseConfig.personalWalletId ||
              target.id == SupabaseConfig.sharedWalletId)
          ? WalletRepository.seededBudgets(target.id)
          : const [],
      members: (target.id == SupabaseConfig.personalWalletId ||
              target.id == SupabaseConfig.sharedWalletId)
          ? WalletRepository.seededMembers(target.id)
          : const [],
    );

    await _loadAndSubscribe();
  }

  Future<void> switchWalletType({required bool shared}) async {
    _hasUserSwitchedWallet = true;
    final matching = state.availableWallets
        .where((w) => w.isShared == shared)
        .toList();
    if (matching.isNotEmpty) {
      if (state.isSharedWallet == shared &&
          matching.any((w) => w.id == state.activeWalletId)) {
        return;
      }
      await selectWallet(matching.first.id);
      return;
    }

    // Fallback untuk state demo tanpa koneksi
    final targetId = shared
        ? SupabaseConfig.sharedWalletId
        : SupabaseConfig.personalWalletId;
    if (state.activeWalletId == targetId) return;
    final nextRole = shared && _user?.id == SupabaseConfig.demoViewerId
        ? 'viewer'
        : 'owner';

    state = state.copyWith(
      activeWalletId: targetId,
      isSharedWallet: shared,
      transactions: WalletRepository.seededTransactions(targetId),
      budgets: WalletRepository.seededBudgets(targetId),
      members: WalletRepository.seededMembers(targetId),
      activeRole: nextRole,
    );

    await _loadAndSubscribe();
  }

  Future<WalletInfo> createSharedWallet(String name) async {
    final userId = _user?.id ?? SupabaseConfig.demoOwnerId;
    final created = await _repo.createSharedWallet(name: name, userId: userId);
    final updatedWallets = [...state.availableWallets, created];
    state = state.copyWith(availableWallets: updatedWallets);
    await selectWallet(created.id);
    return created;
  }

  Future<void> joinSharedWallet(String inviteCode) async {
    final joinedId = await _repo.joinSharedWalletByCode(inviteCode: inviteCode);
    await refreshWallets(selectWalletId: joinedId);
  }

  Future<void> updateMemberRole({
    required String targetUserId,
    required String newRole,
  }) async {
    await _repo.updateMemberRole(
      walletId: state.activeWalletId,
      targetUserId: targetUserId,
      newRole: newRole,
      activeUserRole: state.activeRole,
    );

    final updatedMembers = state.members
        .map((m) => m.userId == targetUserId ? m.copyWith(role: newRole) : m)
        .toList();
    state = state.copyWith(members: updatedMembers);
  }

  Future<void> removeMember(String targetUserId) async {
    await _repo.removeMember(
      walletId: state.activeWalletId,
      targetUserId: targetUserId,
      activeUserRole: state.activeRole,
    );

    final updatedMembers =
        state.members.where((m) => m.userId != targetUserId).toList();
    state = state.copyWith(members: updatedMembers);
  }

  void selectMonth(String monthPeriod) {
    state = state.copyWith(selectedMonth: monthPeriod);
  }

  /// Simulasi mode Offline <-> Online untuk menguji antrean SQLite & deduplikasi `client_tx_id` (`TC-SYNC-03`).
  Future<void> toggleOfflineMode() async {
    final nextOffline = !state.isOfflineMode;
    state = state.copyWith(isOfflineMode: nextOffline);

    if (!nextOffline) {
      state = state.copyWith(isSyncing: true);
      final stopwatch = Stopwatch()..start();
      await _repo.syncEngine.syncPendingToSupabase();
      final remaining = await _repo.syncEngine.getPendingCount();
      final cleared = state.transactions
          .map((tx) => tx.copyWith(isPendingSync: false))
          .toList();
      stopwatch.stop();
      if (!mounted) return;
      state = state.copyWith(
        transactions: cleared,
        pendingSyncCount: remaining,
        isSyncing: false,
        lastSyncLatencyMs: stopwatch.elapsedMilliseconds,
      );
      await _loadAndSubscribe();
    }
  }

  Future<TransactionItem> addTransaction({
    required String merchantName,
    required String category,
    required int amount,
    required String source,
    DateTime? txDate,
    String? receiptUrl,
  }) async {
    final user = _user;
    final created = await _repo.addTransaction(
      walletId: state.activeWalletId,
      userId: user?.id ?? SupabaseConfig.demoOwnerId,
      userName: user?.fullName ?? SupabaseConfig.demoOwnerName,
      userRole: state.activeRole,
      merchantName: merchantName,
      category: category,
      amount: amount,
      source: source,
      txDate: txDate,
      receiptUrl: receiptUrl,
      isOffline: state.isOfflineMode,
    );

    final updatedList = [created, ...state.transactions];
    final pendingCount = state.isOfflineMode
        ? await _repo.syncEngine.getPendingCount()
        : state.pendingSyncCount;

    state = state.copyWith(
      transactions: updatedList,
      pendingSyncCount: pendingCount,
    );
    return created;
  }

  Future<void> updateTransaction({
    required TransactionItem tx,
    required String merchantName,
    required String category,
    required int amount,
  }) async {
    await _repo.updateTransaction(
      tx: tx,
      activeUserRole: state.activeRole,
      newMerchantName: merchantName,
      newCategory: category,
      newAmount: amount,
    );

    final updatedList = state.transactions.map((item) {
      if (item.clientTxId == tx.clientTxId) {
        return item.copyWith(
          merchantName: merchantName,
          category: CategoryTaxonomy.normalize(category),
          amount: amount,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return item;
    }).toList();

    state = state.copyWith(transactions: updatedList);
  }

  Future<void> deleteTransaction(TransactionItem tx) async {
    await _repo.deleteTransaction(tx: tx, activeUserRole: state.activeRole);
    final updatedList = state.transactions
        .where((item) => item.clientTxId != tx.clientTxId)
        .toList();
    state = state.copyWith(transactions: updatedList);
  }

  Future<void> saveBudgetLimit({
    required String category,
    required int limitAmount,
  }) async {
    await _repo.upsertBudgetLimit(
      walletId: state.activeWalletId,
      activeUserRole: state.activeRole,
      category: category,
      monthPeriod: state.selectedMonth,
      limitAmount: limitAmount,
    );

    final normalizedCat = CategoryTaxonomy.normalize(category);
    final updated = [...state.budgets];
    final idx = updated.indexWhere(
      (b) => b.category == normalizedCat && b.monthPeriod == state.selectedMonth,
    );
    if (idx >= 0) {
      updated[idx] = updated[idx].copyWith(
        limitAmount: limitAmount,
        updatedAt: DateTime.now().toUtc(),
      );
    } else {
      updated.add(
        BudgetItem(
          id: 'local-$normalizedCat',
          walletId: state.activeWalletId,
          category: normalizedCat,
          monthPeriod: state.selectedMonth,
          limitAmount: limitAmount,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }

    state = state.copyWith(budgets: updated);
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return WalletRepository(supabaseClient: client);
});

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((
  ref,
) {
  final repo = ref.watch(walletRepositoryProvider);
  final auth = ref.watch(authProvider);
  return WalletNotifier(repository: repo, currentUser: auth.user);
});

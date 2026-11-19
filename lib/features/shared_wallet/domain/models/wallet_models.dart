import 'package:finku_app/core/constants/category_taxonomy.dart';

/// Model domain transaksi keuangan yang tersinkronisasi dengan `public.transactions`.
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.clientTxId,
    required this.walletId,
    required this.createdBy,
    required this.authorName,
    required this.authorRole,
    required this.merchantName,
    required this.category,
    required this.amount,
    required this.source,
    this.receiptUrl,
    required this.txDate,
    required this.createdAt,
    required this.updatedAt,
    this.isPendingSync = false,
  });

  final String id;
  final String clientTxId;
  final String walletId;
  final String createdBy;
  final String authorName;
  final String authorRole;
  final String merchantName;
  final String category;
  final int amount;
  final String source; // 'manual' | 'ocr' | 'ai_chat'
  final String? receiptUrl;
  final DateTime txDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPendingSync;

  String get monthPeriod =>
      '${txDate.year.toString().padLeft(4, '0')}-${txDate.month.toString().padLeft(2, '0')}';

  TransactionItem copyWith({
    String? id,
    String? clientTxId,
    String? walletId,
    String? createdBy,
    String? authorName,
    String? authorRole,
    String? merchantName,
    String? category,
    int? amount,
    String? source,
    String? receiptUrl,
    DateTime? txDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPendingSync,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      clientTxId: clientTxId ?? this.clientTxId,
      walletId: walletId ?? this.walletId,
      createdBy: createdBy ?? this.createdBy,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      merchantName: merchantName ?? this.merchantName,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      source: source ?? this.source,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      txDate: txDate ?? this.txDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  factory TransactionItem.fromSupabaseMap(
    Map<String, dynamic> map, {
    Map<String, WalletMemberInfo> membersByUserId = const {},
  }) {
    final createdById = map['created_by'] as String? ?? '';
    final member = membersByUserId[createdById];
    return TransactionItem(
      id: map['id']?.toString() ?? map['client_tx_id']?.toString() ?? '',
      clientTxId: map['client_tx_id']?.toString() ?? '',
      walletId: map['wallet_id']?.toString() ?? '',
      createdBy: createdById,
      authorName: member?.fullName ?? 'Anggota',
      authorRole: member?.role ?? 'editor',
      merchantName: map['merchant_name']?.toString() ?? 'Transaksi',
      category: CategoryTaxonomy.normalize(map['category']?.toString() ?? ''),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      source: map['source']?.toString() ?? 'manual',
      receiptUrl: map['receipt_url']?.toString(),
      txDate:
          DateTime.tryParse(map['tx_date']?.toString() ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      isPendingSync: false,
    );
  }
}

/// Model anggaran bulanan per kategori (`public.budgets`).
class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.walletId,
    required this.category,
    required this.monthPeriod,
    required this.limitAmount,
    required this.updatedAt,
  });

  final String id;
  final String walletId;
  final String category;
  final String monthPeriod;
  final int limitAmount;
  final DateTime updatedAt;

  BudgetItem copyWith({int? limitAmount, DateTime? updatedAt}) {
    return BudgetItem(
      id: id,
      walletId: walletId,
      category: category,
      monthPeriod: monthPeriod,
      limitAmount: limitAmount ?? this.limitAmount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BudgetItem.fromSupabaseMap(Map<String, dynamic> map) {
    return BudgetItem(
      id: map['id']?.toString() ?? '',
      walletId: map['wallet_id']?.toString() ?? '',
      category: CategoryTaxonomy.normalize(map['category']?.toString() ?? ''),
      monthPeriod: map['month_period']?.toString() ?? '2026-11',
      limitAmount: (map['limit_amount'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Informasi anggota dan perannya dalam dompet kolaborasi (`public.wallet_members`).
class WalletMemberInfo {
  const WalletMemberInfo({
    required this.walletId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.avatarInitials,
    required this.role,
    this.avatarUrl,
  });

  final String walletId;
  final String userId;
  final String fullName;
  final String email;
  final String avatarInitials;
  final String role; // 'owner' | 'editor' | 'viewer'
  final String? avatarUrl;

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'editor':
        return 'Editor';
      default:
        return 'Viewer';
    }
  }

  WalletMemberInfo copyWith({String? role, String? avatarUrl}) {
    return WalletMemberInfo(
      walletId: walletId,
      userId: userId,
      fullName: fullName,
      email: email,
      avatarInitials: avatarInitials,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

/// Informasi ringkas dompet (`public.wallets` + peran pengguna aktif di `wallet_members`).
class WalletInfo {
  const WalletInfo({
    required this.id,
    required this.name,
    required this.isShared,
    this.role = 'owner',
    this.inviteCode,
    this.createdBy = '',
    this.totalBalance = 8250000,
  });

  final String id;
  final String name;
  final bool isShared;
  final String role; // 'owner' | 'editor' | 'viewer'
  final String? inviteCode;
  final String createdBy;
  final int totalBalance;

  bool get canEdit => role == 'owner' || role == 'editor';
  bool get isOwner => role == 'owner';

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'editor':
        return 'Editor';
      default:
        return 'Viewer';
    }
  }

  WalletInfo copyWith({
    String? name,
    bool? isShared,
    String? role,
    String? inviteCode,
  }) {
    return WalletInfo(
      id: id,
      name: name ?? this.name,
      isShared: isShared ?? this.isShared,
      role: role ?? this.role,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy,
      totalBalance: totalBalance,
    );
  }
}

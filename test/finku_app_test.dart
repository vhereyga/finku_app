import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finku_app/core/config/supabase_config.dart';
import 'package:finku_app/core/constants/category_taxonomy.dart';
import 'package:finku_app/core/sync/offline_sync_engine.dart';
import 'package:finku_app/core/theme/app_theme.dart';
import 'package:finku_app/core/utils/currency_normalizer.dart';
import 'package:finku_app/features/auth/domain/entities/app_user.dart';
import 'package:finku_app/features/auth/presentation/pages/login_page.dart';
import 'package:finku_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:finku_app/features/budget_analytics/domain/models/budget_summary.dart';
import 'package:finku_app/features/budget_analytics/presentation/pages/budget_dashboard_page.dart';
import 'package:finku_app/features/fingpt_chat/data/fingpt_service.dart';
import 'package:finku_app/features/fingpt_chat/presentation/pages/fingpt_chat_page.dart';
import 'package:finku_app/features/ocr_scan/data/ocr_service.dart';
import 'package:finku_app/features/ocr_scan/presentation/pages/ocr_scan_page.dart';
import 'package:finku_app/features/settings/presentation/pages/settings_page.dart';
import 'package:finku_app/features/shared_wallet/data/wallet_repository.dart';
import 'package:finku_app/features/shared_wallet/domain/models/wallet_models.dart';
import 'package:finku_app/features/shared_wallet/presentation/pages/shared_wallet_page.dart';
import 'package:finku_app/features/shared_wallet/presentation/providers/wallet_provider.dart';

Set<String> _collectSemanticsIdentifiers(WidgetTester tester) {
  final ids = <String>{};
  for (final widget in tester.widgetList<Semantics>(find.byType(Semantics))) {
    final id = widget.properties.identifier;
    if (id != null && id.isNotEmpty) {
      ids.add(id);
    }
  }
  return ids;
}

class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(AppUser user) : super(supabaseClient: null) {
    state = AuthState(user: user);
  }
}

void main() {
  group('Modul 1 & Core: CurrencyNormalizer & OCR Extraction (TC-OCR-01..04)', () {
    test('parseRupiah normalizes dot, comma-decimal, and slang formats', () {
      expect(CurrencyNormalizer.parseRupiah('15.000'), 15000);
      expect(CurrencyNormalizer.parseRupiah('Rp 15.000,-'), 15000);
      expect(CurrencyNormalizer.parseRupiah('15,000.00'), 15000);
      expect(CurrencyNormalizer.parseRupiah('1,250,500.00'), 1250500);
      expect(CurrencyNormalizer.parseRupiah('Rp 25.604,-'), 25604);
      expect(CurrencyNormalizer.parseRupiah('50rb'), 50000);
      expect(CurrencyNormalizer.parseRupiah('2ribu'), 2000);
      expect(CurrencyNormalizer.parseRupiah('18k'), 18000);
      expect(CurrencyNormalizer.parseRupiah('1.5jt'), 1500000);
      expect(CurrencyNormalizer.formatRupiah(1500000), 'Rp 1.500.000');
      expect(CurrencyNormalizer.formatRupiah(-250000), '-Rp 250.000');
    });

    test('OcrService parses all 4 test presets accurately (>= 90%)', () async {
      final ocr = OcrService();

      final tc1 = await ocr.scanPreset('TC-OCR-01');
      expect(tc1.merchantName, 'Indomaret Sudirman');
      expect(tc1.totalAmount, 25604);
      expect(tc1.suggestedCategory, CategoryTaxonomy.belanjaHarian);

      final tc2 = await ocr.scanPreset('TC-OCR-02');
      expect(tc2.merchantName, 'Alfamart Kemang');
      expect(tc2.totalAmount, 35000);

      final tc3 = await ocr.scanPreset('TC-OCR-03');
      expect(tc3.merchantName, 'Superindo Dago');
      expect(tc3.totalAmount, 84000);

      final tc4 = await ocr.scanPreset('TC-OCR-04');
      expect(tc4.merchantName, 'Starbucks Reserve');
      expect(tc4.totalAmount, 88000);
      expect(tc4.suggestedCategory, CategoryTaxonomy.makananMinuman);
    });
  });

  group('Modul 2: FinGPT NLP Parser & Category Taxonomy (TC-AI-01..04)', () {
    final finGpt = FinGptService();

    test('TC-AI-02 splits compound Indonesian slang into 3 transactions', () {
      final resp = finGpt.parseNaturalLanguage(
        'Beli bensin 50rb, parkir 2rb, sama jajan kopi 18k pakai OVO',
      );
      expect(resp.needsClarification, isFalse);
      expect(resp.transactions.length, 3);
      expect(resp.totalAmount, 70000);

      expect(resp.transactions[0].amount, 50000);
      expect(resp.transactions[0].category, CategoryTaxonomy.transportasi);
      expect(resp.transactions[0].walletName, 'OVO');

      expect(resp.transactions[1].amount, 2000);
      expect(resp.transactions[1].category, CategoryTaxonomy.transportasi);

      expect(resp.transactions[2].amount, 18000);
      expect(resp.transactions[2].category, CategoryTaxonomy.makananMinuman);
    });

    test('TC-AI-03 rejects ambiguous prompt without creating Rp0 transaction', () {
      final resp = finGpt.parseNaturalLanguage(
        'Tadi habis bayar tagihan bulanan',
      );
      expect(resp.needsClarification, isTrue);
      expect(resp.transactions, isEmpty);
      expect(resp.clarificationMessage, isNotNull);
    });

    test('TC-AI-04 strictly maps outputs to 8 official categories', () {
      for (final sample in [
        'Makan nasi padang 30rb',
        'Isi bensin pertamax 100rb',
        'Belanja indomaret 45rb',
        'Bayar listrik PLN 200rb',
        'Nonton bioskop XXI 60rb',
        'Beli vitamin apotek 75rb',
        'Beli buku kuliah 120rb',
      ]) {
        final resp = finGpt.parseNaturalLanguage(sample);
        expect(resp.transactions, isNotEmpty);
        expect(
          CategoryTaxonomy.validCategories,
          contains(resp.transactions.first.category),
        );
      }
    });
  });

  group('Modul 3: Offline Sync Queue & Per-Wallet RBAC Guards (TC-SYNC-03..04)', () {
    test('OfflineSyncEngine queues UUID v4 client_tx_id without duplicates', () async {
      final engine = OfflineSyncEngine(supabaseClient: null);
      final rec = await engine.enqueueTransaction(
        walletId: SupabaseConfig.sharedWalletId,
        createdBy: SupabaseConfig.demoOwnerId,
        merchantName: 'Galon Kos Offline',
        category: CategoryTaxonomy.belanjaHarian,
        amount: 21000,
        source: 'manual',
        txDate: '2026-11-18',
        isOffline: true,
      );
      expect(rec.clientTxId, isNotEmpty);
      expect(await engine.getPendingCount(), 1);
    });

    test('WalletRepository rejects mutations by viewer role and non-owner member edits', () async {
      final repo = WalletRepository(supabaseClient: null);
      expect(
        () => repo.addTransaction(
          walletId: SupabaseConfig.sharedWalletId,
          userId: SupabaseConfig.demoViewerId,
          userName: 'Raka Pratama',
          userRole: 'viewer',
          merchantName: 'Blocked',
          category: CategoryTaxonomy.lainnya,
          amount: 10000,
          source: 'manual',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => repo.updateMemberRole(
          walletId: SupabaseConfig.sharedWalletId,
          targetUserId: SupabaseConfig.demoViewerId,
          newRole: 'editor',
          activeUserRole: 'editor',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('Viewer in shared wallet still owns their Personal Wallet (Mode Biasa)', () async {
      const rakaUser = AppUser(
        id: SupabaseConfig.demoViewerId,
        email: SupabaseConfig.demoViewerEmail,
        fullName: SupabaseConfig.demoViewerName,
        avatarInitials: 'RP',
      );
      final notifier = WalletNotifier(
        repository: WalletRepository(supabaseClient: null),
        currentUser: rakaUser,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Mode Biasa (Dompet Pribadi): user memiliki akses penuh ('owner')
      expect(notifier.state.isSharedWallet, isFalse);
      expect(notifier.state.activeRole, 'owner');
      expect(notifier.state.canEdit, isTrue);

      // Pindah ke Mode Bersama: peran per-dompet Raka menjadi 'viewer'
      await notifier.switchWalletType(shared: true);
      expect(notifier.state.isSharedWallet, isTrue);
      expect(notifier.state.activeRole, 'viewer');
      expect(notifier.state.canEdit, isFalse);
      notifier.dispose();
    });
  });

  group('Modul 4: Budget Analytics Math & Thresholds (TC-VIS-01..04)', () {
    test('TC-VIS-01..04 accurate percentages, colors, extreme disparity, empty state', () {
      expect(
        BudgetSummary.thresholdForRatio(0.72),
        BudgetThresholdStatus.safe,
      );
      expect(
        BudgetSummary.thresholdForRatio(0.85),
        BudgetThresholdStatus.warning,
      );
      expect(
        BudgetSummary.thresholdForRatio(1.10),
        BudgetThresholdStatus.overbudget,
      );

      final extremeTxs = [
        TransactionItem(
          id: '1',
          clientTxId: 'c1',
          walletId: 'w1',
          createdBy: 'u1',
          authorName: 'Budi',
          authorRole: 'owner',
          merchantName: 'Besar',
          category: CategoryTaxonomy.tagihanUtilitas,
          amount: 10000000,
          source: 'manual',
          txDate: DateTime(2026, 11, 10),
          createdAt: DateTime(2026, 11, 10),
          updatedAt: DateTime(2026, 11, 10),
        ),
        TransactionItem(
          id: '2',
          clientTxId: 'c2',
          walletId: 'w1',
          createdBy: 'u1',
          authorName: 'Budi',
          authorRole: 'owner',
          merchantName: 'Parkir Kecil',
          category: CategoryTaxonomy.transportasi,
          amount: 1000,
          source: 'manual',
          txDate: DateTime(2026, 11, 11),
          createdAt: DateTime(2026, 11, 11),
          updatedAt: DateTime(2026, 11, 11),
        ),
      ];

      final summary = BudgetSummary.compute(
        transactions: extremeTxs,
        budgets: const [],
        monthPeriod: '2026-11',
      );
      expect(summary.totalSpend, 10001000);
      expect(summary.categoryShares.length, 2);
      // Visual minimum sweep angle guard (`TC-VIS-03`)
      expect(summary.categoryShares[1].visualPercentage, greaterThanOrEqualTo(3.0));

      // Empty state (`TC-VIS-04`)
      final emptySummary = BudgetSummary.compute(
        transactions: extremeTxs,
        budgets: const [],
        monthPeriod: '2026-12',
      );
      expect(emptySummary.isEmpty, isTrue);
    });
  });

  group('Chapter 6 Maestro Semantics Identifiers Audit', () {
    testWidgets('LoginPage exposes all Auth & Google Sign-In Semantics identifiers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: FinkuTheme.light(), home: const LoginPage()),
        ),
      );
      final ids = _collectSemanticsIdentifiers(tester);
      expect(ids, containsAll([
        'input_login_email',
        'input_login_password',
        'btn_login',
        'btn_google_login',
        'btn_go_register',
        'btn_demo_owner',
        'btn_demo_viewer',
      ]));
    });

    testWidgets('Dashboard, OCR, FinGPT, SharedWallet (Owner/Viewer), Settings expose all Semantics', (tester) async {
      const ownerUser = AppUser(
        id: SupabaseConfig.demoOwnerId,
        email: SupabaseConfig.demoOwnerEmail,
        fullName: SupabaseConfig.demoOwnerName,
        avatarInitials: 'BS',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => _FixedAuthNotifier(ownerUser)),
          ],
          child: MaterialApp(
            theme: FinkuTheme.light(),
            home: BudgetDashboardPage(
              avatarInitials: 'BS',
              onOpenSettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var ids = _collectSemanticsIdentifiers(tester);
      expect(ids, containsAll([
        'btn_open_settings',
        'btn_wallet_switcher',
        'filter_month_selector',
        'filter_wallet_type',
        'chart_monthly_donut',
        'progress_budget_bar',
      ]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => _FixedAuthNotifier(ownerUser)),
          ],
          child: MaterialApp(
            theme: FinkuTheme.light(),
            home: OcrScanPage(avatarInitials: 'BS', onOpenSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ids = _collectSemanticsIdentifiers(tester);
      expect(ids, containsAll([
        'btn_scan_receipt',
        'input_ocr_merchant',
        'input_ocr_total',
        'btn_save_ocr_tx',
      ]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => _FixedAuthNotifier(ownerUser)),
          ],
          child: MaterialApp(
            theme: FinkuTheme.light(),
            home: FinGptChatPage(avatarInitials: 'BS', onOpenSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('input_fingpt_chat')),
        'Beli bensin 50rb, parkir 2rb, sama kopi 18k pakai OVO',
      );
      await tester.tap(find.byKey(const Key('btn_send_fingpt')));
      await tester.pumpAndSettle();
      ids = _collectSemanticsIdentifiers(tester);
      expect(ids, containsAll([
        'input_fingpt_chat',
        'btn_send_fingpt',
        'card_ai_confirmation',
        'btn_confirm_ai_tx',
      ]));

      // SharedWallet as Owner -> shows btn_manage_members, dropdown_member_role, btn_edit_tx, btn_delete_tx
      final ownerSharedContainer = ProviderContainer(
        overrides: [
          authProvider.overrideWith((_) => _FixedAuthNotifier(ownerUser)),
        ],
      );
      addTearDown(ownerSharedContainer.dispose);
      await ownerSharedContainer
          .read(walletProvider.notifier)
          .switchWalletType(shared: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ownerSharedContainer,
          child: MaterialApp(
            theme: FinkuTheme.light(),
            home: SharedWalletPage(avatarInitials: 'BS', onOpenSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ids = _collectSemanticsIdentifiers(tester);
      expect(ids, containsAll([
        'btn_wallet_switcher',
        'badge_sync_status',
        'badge_member_role',
        'btn_manage_members',
        'btn_edit_tx',
        'btn_delete_tx',
      ]));

      await tester.ensureVisible(find.byKey(const Key('btn_manage_members')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_manage_members')));
      await tester.pumpAndSettle();
      ids = _collectSemanticsIdentifiers(tester);
      expect(ids, contains('dropdown_member_role'));
      Navigator.of(tester.element(find.text('Kelola Anggota Dompet'))).pop();
      await tester.pumpAndSettle();

      // SharedWallet as Viewer (Raka) -> hides btn_edit_tx and btn_delete_tx in Shared Wallet (`TC-SYNC-04`)
      const viewerUser = AppUser(
        id: SupabaseConfig.demoViewerId,
        email: SupabaseConfig.demoViewerEmail,
        fullName: SupabaseConfig.demoViewerName,
        avatarInitials: 'RP',
      );
      final viewerSharedContainer = ProviderContainer(
        overrides: [
          authProvider.overrideWith((_) => _FixedAuthNotifier(viewerUser)),
        ],
      );
      addTearDown(viewerSharedContainer.dispose);
      await viewerSharedContainer
          .read(walletProvider.notifier)
          .switchWalletType(shared: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: viewerSharedContainer,
          child: MaterialApp(
            theme: FinkuTheme.light(),
            home: SharedWalletPage(avatarInitials: 'RP', onOpenSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ids = _collectSemanticsIdentifiers(tester);
      expect(ids, containsAll(['badge_sync_status', 'badge_member_role']));
      expect(ids.contains('btn_edit_tx'), isFalse);
      expect(ids.contains('btn_delete_tx'), isFalse);
      expect(ids.contains('btn_manage_members'), isFalse);

      // SettingsPage
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => _FixedAuthNotifier(ownerUser)),
          ],
          child: MaterialApp(
            theme: FinkuTheme.light(),
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ids = _collectSemanticsIdentifiers(tester);
      expect(ids, containsAll([
        'btn_change_avatar',
        'input_budget_limit',
        'btn_save_budget',
        'btn_logout',
      ]));
    });
  });
}

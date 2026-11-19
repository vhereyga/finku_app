import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/budget_analytics/presentation/pages/budget_dashboard_page.dart';
import 'features/fingpt_chat/presentation/pages/fingpt_chat_page.dart';
import 'features/ocr_scan/presentation/pages/ocr_scan_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/shared_wallet/presentation/pages/shared_wallet_page.dart';
import 'features/shared_wallet/presentation/providers/wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib aktif agar pohon Semantics dapat diinspeksi langsung oleh Maestro Studio & Ruby
  SemanticsBinding.instance.ensureSemantics();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: FinkuApp()));
}

class FinkuApp extends ConsumerWidget {
  const FinkuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Finku: Budget & Money Manager',
      debugShowCheckedModeBanner: false,
      theme: FinkuTheme.light(),
      home: authState.isAuthenticated
          ? const FinkuHomeShell()
          : const LoginPage(),
    );
  }
}

/// Shell utama 4 tab sesuai Stitch: Beranda, Scan Struk, FinGPT, Bersama.
class FinkuHomeShell extends ConsumerStatefulWidget {
  const FinkuHomeShell({super.key});

  @override
  ConsumerState<FinkuHomeShell> createState() => _FinkuHomeShellState();
}

class _FinkuHomeShellState extends ConsumerState<FinkuHomeShell> {
  int _currentIndex = 0;

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final initials = user?.avatarInitials ?? 'BS';
    final avatarUrl = user?.avatarUrl;

    final pages = [
      BudgetDashboardPage(
        avatarInitials: initials,
        avatarUrl: avatarUrl,
        onOpenSettings: _openSettings,
      ),
      OcrScanPage(
        avatarInitials: initials,
        avatarUrl: avatarUrl,
        onOpenSettings: _openSettings,
      ),
      FinGptChatPage(
        avatarInitials: initials,
        avatarUrl: avatarUrl,
        onOpenSettings: _openSettings,
      ),
      SharedWalletPage(
        avatarInitials: initials,
        avatarUrl: avatarUrl,
        onOpenSettings: _openSettings,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: FinkuColors.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: FinkuColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: FinkuColors.surfaceContainerLowest,
          indicatorColor: FinkuColors.primaryBrand.withValues(alpha: 0.12),
          onDestinationSelected: (idx) {
            if (idx == 3) {
              ref.read(walletProvider.notifier).switchWalletType(shared: true);
            }
            setState(() => _currentIndex = idx);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(
                Icons.account_balance_wallet_rounded,
                color: FinkuColors.primaryBrand,
              ),
              label: 'Beranda',
            ),
            const NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(
                Icons.document_scanner_rounded,
                color: FinkuColors.primaryBrand,
              ),
              label: 'Scan Struk',
            ),
            const NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(
                Icons.auto_awesome_rounded,
                color: FinkuColors.primaryBrand,
              ),
              label: 'FinGPT',
            ),
            NavigationDestination(
              icon: Badge(
                label: const Text('SYNC'),
                backgroundColor: FinkuColors.primary,
                child: const Icon(Icons.group_outlined),
              ),
              selectedIcon: Badge(
                label: const Text('SYNC'),
                backgroundColor: FinkuColors.primaryBrand,
                child: const Icon(
                  Icons.group_rounded,
                  color: FinkuColors.primaryBrand,
                ),
              ),
              label: 'Bersama',
            ),
          ],
        ),
      ),
    );
  }
}

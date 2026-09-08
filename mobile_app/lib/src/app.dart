import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/profile_repository_impl.dart';
import 'data/repositories/purchase_repository_impl.dart';
import 'data/repositories/wallet_repository_impl.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/profile_controller.dart';
import 'presentation/controllers/purchase_controller.dart';
import 'presentation/controllers/wallet_controller.dart';
import 'presentation/controllers/admin_dashboard_controller.dart';
import 'presentation/controllers/audit_controller.dart';
import 'presentation/controllers/notification_controller.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/main_layout_screen.dart';
import 'presentation/widgets/animated_grog_frog.dart';

class GrogApp extends StatelessWidget {
  const GrogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepositoryImpl();
    final profileRepository = ProfileRepositoryImpl();
    final walletRepository = WalletRepositoryImpl();
    final purchaseRepository = PurchaseRepositoryImpl();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create:
              (_) =>
                  AuthController(authRepository: authRepository)..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => WalletController(walletRepository: walletRepository),
        ),
        ChangeNotifierProvider(
          create:
              (_) => ProfileController(profileRepository: profileRepository),
        ),
        ChangeNotifierProvider(
          create:
              (_) => PurchaseController(purchaseRepository: purchaseRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminDashboardController(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationController(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuditController(),
        ),
      ],
      child: MaterialApp(
        title: 'Grog',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.loading) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AnimatedGrogFrog(size: 130),
                  const SizedBox(height: 24),
                  const Text(
                    'GROG',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4F46E5),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (auth.isAuthenticated) {
          return const MainLayoutScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

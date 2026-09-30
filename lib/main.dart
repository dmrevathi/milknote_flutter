import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_provider.dart';
import 'services/lang_provider.dart';
import 'services/ad_service.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_milk_screen.dart';
import 'screens/daily_report_screen.dart';
import 'screens/monthly_report_screen.dart';
import 'screens/full_report_screen.dart';
import 'screens/register_cow_screen.dart';
import 'screens/connect_cow_screen.dart';
import 'screens/edit_milk_screen.dart';
import 'screens/cow_monthly_screen.dart';
import 'screens/dist_daily_screen.dart';
import 'screens/dist_customers_screen.dart';
import 'screens/dist_add_customer_screen.dart';
import 'screens/dist_card_screen.dart';
import 'screens/payment_status_screen.dart';
import 'services/dist_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LangProvider()),
      ],
      child: const MilkNoteApp(),
    ),
  );
}

class MilkNoteApp extends StatelessWidget {
  const MilkNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final router = GoRouter(
      initialLocation: auth.isLoggedIn ? auth.homeRoute : '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        final loggedIn = auth.isLoggedIn;
        final loc = state.matchedLocation;
        final onPublic = loc == '/login' || loc == '/signup';

        if (!loggedIn && !onPublic) return '/login';
        if (loggedIn && loc == '/login') {
          return auth.homeRoute;
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => SignupScreen()),
        GoRoute(
          path: '/edit-milk',
          builder: (_, state) {
            final extra = state.extra as Map<String, String>;
            return EditMilkScreen(
              connectionId: extra['connection_id']!,
              date: extra['date']!,
            );
          },
        ),
        GoRoute(
          path: '/dist-add-customer',
          builder: (_, __) => const DistAddCustomerScreen(),
        ),
        GoRoute(
          path: '/dist-card',
          builder: (_, state) {
            final extra = state.extra as Map;
            return DistCardScreen(
              customerId: toInt(extra['customer_id']),
              title: extra['name']?.toString() ?? '',
              month: extra['month']?.toString(),
            );
          },
        ),
        ShellRoute(
          builder: (context, state, child) => HomeScreen(
            child: child,
            isCowPerson: auth.isCowPerson,
            roleId: auth.roleId ?? '',
          ),
          routes: [
            GoRoute(path: '/add-milk', builder: (_, __) => AddMilkScreen()),
            GoRoute(path: '/daily-report', builder: (_, __) => DailyReportScreen()),
            GoRoute(path: '/monthly-report', builder: (_, __) => MonthlyReportScreen()),
            GoRoute(path: '/full-report', builder: (_, __) => FullReportScreen()),
            GoRoute(path: '/register-cow', builder: (_, __) => RegisterCowScreen()),
            GoRoute(path: '/connect-cow', builder: (_, __) => ConnectCowScreen()),
            GoRoute(path: '/cow-monthly', builder: (_, __) => CowMonthlyScreen()),
            GoRoute(path: '/dist-daily', builder: (_, __) => const DistDailyScreen()),
            GoRoute(path: '/dist-customers', builder: (_, __) => const DistCustomersScreen()),
            GoRoute(path: '/pay-status', builder: (_, __) => const PaymentStatusScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Milk Note',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
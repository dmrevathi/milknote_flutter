import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_provider.dart';
import 'services/ad_service.dart';
import 'services/lang_provider.dart';
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
      initialLocation: auth.isLoggedIn
          ? (auth.isCowPerson ? '/cow-monthly' : '/add-milk')
          : '/login',
      routes: [
        // Public routes
        GoRoute(path: '/login', builder: (_, __) => LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => SignupScreen()),

        // Edit milk - full screen no drawer
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

        // Shell with drawer
        ShellRoute(
          builder: (context, state, child) =>
              HomeScreen(child: child, isCowPerson: auth.isCowPerson),
          routes: [
            GoRoute(path: '/add-milk', builder: (_, __) => AddMilkScreen()),
            GoRoute(path: '/daily-report', builder: (_, __) => DailyReportScreen()),
            GoRoute(path: '/monthly-report', builder: (_, __) => MonthlyReportScreen()),
            GoRoute(path: '/full-report', builder: (_, __) => FullReportScreen()),
            GoRoute(path: '/register-cow', builder: (_, __) => RegisterCowScreen()),
            GoRoute(path: '/connect-cow', builder: (_, __) => ConnectCowScreen()),
            GoRoute(path: '/cow-monthly', builder: (_, __) => CowMonthlyScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'MilkNote',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

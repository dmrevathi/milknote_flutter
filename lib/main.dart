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

class MilkNoteApp extends StatefulWidget {
  const MilkNoteApp({super.key});
  @override
  State<MilkNoteApp> createState() => _MilkNoteAppState();
}

class _MilkNoteAppState extends State<MilkNoteApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        // Wait until auth is loaded
        if (auth.isLoading) return null;

        final loggedIn = auth.isLoggedIn;
        final loc = state.matchedLocation;
        final onPublic = loc == '/login' || loc == '/signup';

        // Not logged in — send to login
        if (!loggedIn && !onPublic) return '/login';

        // Logged in — send away from login
        if (loggedIn && loc == '/login') {
          return auth.isCowPerson ? '/cow-monthly' : '/add-milk';
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
        ShellRoute(
          builder: (context, state, child) => HomeScreen(
            child: child,
            isCowPerson: context.read<AuthProvider>().isCowPerson,
          ),
          routes: [
            GoRoute(path: '/add-milk', builder: (_, __) => AddMilkScreen()),
            GoRoute(
                path: '/daily-report', builder: (_, __) => DailyReportScreen()),
            GoRoute(
                path: '/monthly-report',
                builder: (_, __) => MonthlyReportScreen()),
            GoRoute(
                path: '/full-report', builder: (_, __) => FullReportScreen()),
            GoRoute(
                path: '/register-cow', builder: (_, __) => RegisterCowScreen()),
            GoRoute(
                path: '/connect-cow', builder: (_, __) => ConnectCowScreen()),
            GoRoute(
                path: '/cow-monthly', builder: (_, __) => CowMonthlyScreen()),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Milk Note',
      theme: appTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

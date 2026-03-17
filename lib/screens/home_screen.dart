import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_provider.dart';
import '../services/lang_provider.dart';
import '../theme.dart';

final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.milknote.app';

class HomeScreen extends StatelessWidget {
  final Widget child;
  final bool isCowPerson;

  const HomeScreen({super.key, required this.child, required this.isCowPerson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: rootScaffoldKey,
      drawer: _AppDrawer(isCowPerson: isCowPerson),
      body: child,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final bool isCowPerson;
  const _AppDrawer({required this.isCowPerson});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.watch<LangProvider>();
    final t = lang.t;

    void go(String route) {
      rootScaffoldKey.currentState?.closeDrawer();
      context.go(route);
    }

    void shareApp() {
      rootScaffoldKey.currentState?.closeDrawer();
      final shareMsg = '🥛 *Milk Note App*\n\n'
          '${t['login']?['footer'] ?? 'Digital milk record app'}\n\n'
          '👉 Download: $_playStoreUrl\n\n'
          'Call: 8825401886';
      Share.share(shareMsg, subject: 'Milk Note App');
    }

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: kGreen),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/icon/app_icon.png',
                    width: 52,
                    height: 52,
                  ),
                  const SizedBox(height: 8),
                  const Text('Milk Note',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),

          // Language switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.language, color: kGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  value: lang.lang,
                  isExpanded: true,
                  underline: const SizedBox(),
                  isDense: true,
                  items: kLanguages
                      .map((l) => DropdownMenuItem(
                            value: l['code'],
                            child: Text(l['label']!,
                                style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: (code) {
                    if (code != null) lang.setLanguage(code);
                  },
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Milk person menus
          if (!isCowPerson) ...[
            _DrawerItem(
                icon: Icons.add_circle_outline,
                label: t['sideBar']?['addMilkRecord'] ?? 'Add Milk',
                onTap: () => go('/add-milk')),
            _DrawerItem(
                icon: Icons.today,
                label: t['sideBar']?['todayMilkRecord'] ?? 'Today Report',
                onTap: () => go('/daily-report')),
            _DrawerItem(
                icon: Icons.calendar_month,
                label: t['sideBar']?['monthlyMilkRecord'] ?? 'Monthly Report',
                onTap: () => go('/monthly-report')),
            _DrawerItem(
                icon: Icons.assessment,
                label: t['sideBar']?['allMilkRecord'] ?? 'Full Report',
                onTap: () => go('/full-report')),
            _DrawerItem(
                icon: Icons.person_add,
                label: t['sideBar']?['registerMilkPerson'] ??
                    'Register Cow Person',
                onTap: () => go('/register-cow')),
            _DrawerItem(
                icon: Icons.link,
                label: t['sideBar']?['addMilkPerson'] ?? 'Connect Cow Person',
                onTap: () => go('/connect-cow')),
          ],

          // Cow person menus
          if (isCowPerson) ...[
            _DrawerItem(
                icon: Icons.bar_chart,
                label: t['sideBar']?['milkManMonthlyMilkValue'] ??
                    'Monthly Report',
                onTap: () => go('/cow-monthly')),
          ],

          const Divider(),

          // Share app
          _DrawerItem(
            icon: Icons.share,
            label: 'Share App',
            color: Colors.blue.shade700,
            onTap: shareApp,
          ),

          const Spacer(),
          const Divider(),

          // Logout
          _DrawerItem(
            icon: Icons.logout,
            label: t['sideBar']?['logout'] ?? 'Logout',
            color: kRed,
            onTap: () {
              // Close drawer first, then show dialog using root scaffold context
              rootScaffoldKey.currentState?.closeDrawer();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (rootScaffoldKey.currentContext == null) return;
                showDialog<bool>(
                  context: rootScaffoldKey.currentContext!,
                  builder: (_) => AlertDialog(
                    title: Text(t['logout']?['title'] ?? 'Logout'),
                    content: Text(t['logout']?['confirmationText'] ??
                        'Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(
                            rootScaffoldKey.currentContext!, false),
                        child: Text(t['monthlyCalc']?['cancel'] ?? 'Cancel',
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kRed),
                        onPressed: () {
                          Navigator.pop(rootScaffoldKey.currentContext!, true);
                          auth.logout();
                        },
                        child: Text(t['logout']?['logoutButton'] ?? 'Logout'),
                      ),
                    ],
                  ),
                );
              });
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? kGreen),
      title: Text(label,
          style: TextStyle(
              color: color ?? Colors.black87, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

// Reusable AppBar
class MilkNoteAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const MilkNoteAppBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

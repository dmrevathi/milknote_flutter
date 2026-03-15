import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_provider.dart';
import '../theme.dart';

final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

// Play Store link — update once published
const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.milknote.app';

const String _shareMessage = '🥛 *MilkNote App*\n\n'
    'பால் கணக்கு வைக்க எளிதான ஆப்!\n'
    'உங்கள் தினசரி பால் கணக்கை டிஜிட்டலாக வைத்திருங்கள்.\n\n'
    '👉 Download here:\n$_playStoreUrl\n\n'
    'சேவைக்கு: 8825401886';

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

    void go(String route) {
      rootScaffoldKey.currentState?.closeDrawer();
      context.go(route);
    }

    void shareApp() {
      rootScaffoldKey.currentState?.closeDrawer();
      Share.share(
        _shareMessage,
        subject: 'MilkNote - பால் கணக்கு ஆப்',
      );
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
                children: const [
                  Text('🥛', style: TextStyle(fontSize: 36)),
                  SizedBox(height: 8),
                  Text('Milk Note',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),

          // Milk person menus
          if (!isCowPerson) ...[
            _DrawerItem(
                icon: Icons.add_circle_outline,
                label: 'பால் கணக்கு சேர்',
                onTap: () => go('/add-milk')),
            _DrawerItem(
                icon: Icons.today,
                label: 'இன்றைய பால் கணக்கு',
                onTap: () => go('/daily-report')),
            _DrawerItem(
                icon: Icons.calendar_month,
                label: 'மாதாந்திர பால் கணக்கு',
                onTap: () => go('/monthly-report')),
            _DrawerItem(
                icon: Icons.assessment,
                label: 'முழு பால் கணக்கு',
                onTap: () => go('/full-report')),
            _DrawerItem(
                icon: Icons.person_add,
                label: 'மாட்டுக்காரரை பதிவு செய்',
                onTap: () => go('/register-cow')),
            _DrawerItem(
                icon: Icons.link,
                label: 'மாட்டுக்காரரை இணை',
                onTap: () => go('/connect-cow')),
          ],

          // Cow person menus
          if (isCowPerson) ...[
            _DrawerItem(
                icon: Icons.bar_chart,
                label: 'மாதாந்திர பால் கணக்கு',
                onTap: () => go('/cow-monthly')),
          ],

          const Divider(),

          // Share app — visible to all roles
          _DrawerItem(
            icon: Icons.share,
            label: 'ஆப்பை பகிர்',
            color: Colors.blue.shade700,
            onTap: shareApp,
          ),

          const Spacer(),
          const Divider(),

          // Logout
          _DrawerItem(
            icon: Icons.logout,
            label: 'வெளியேறு',
            color: kRed,
            onTap: () async {
              rootScaffoldKey.currentState?.closeDrawer();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('வெளியேறு'),
                  content: const Text('நீங்கள் வெளியேற விரும்புகிறீர்களா?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ரத்து',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kRed),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('வெளியேறு'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await auth.logout();
                if (context.mounted) context.go('/login');
              }
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

// Reusable AppBar with menu button
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

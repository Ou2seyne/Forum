import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'app_themes.dart';
import 'connexion/login_screen.dart';
import 'connexion/register_screen.dart';
import 'user/profile_screen.dart';
import 'home_screen.dart';
import 'admin/admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  runApp(MyApp(initialDarkMode: isDarkMode));
}

class MyApp extends StatelessWidget {
  final bool initialDarkMode;

  const MyApp({super.key, required this.initialDarkMode});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(initialDarkMode),
      child: const AppWrapper(),
    );
  }
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Forum',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/admin': (context) => const AdminWrapper(),
        '/profile': (context) => const ProfileWrapper(),
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Page non trouvée')),
          ),
        );
      },
    );
  }
}

class HomeWrapper extends StatelessWidget {
  const HomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _getUserIdFromPreferences(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userId = snapshot.data;
        return HomeScreen(userId: userId);
      },
    );
  }
}

class ProfileWrapper extends StatelessWidget {
  const ProfileWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _getUserIdFromPreferences(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userId = snapshot.data;
        return userId != null ? ProfileScreen(userId: userId) : const LoginScreen();
      },
    );
  }
}

class AdminWrapper extends StatelessWidget {
  const AdminWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkUserStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userData = snapshot.data;
        if (userData == null || !userData['isLoggedIn']) {
          return const LoginScreen();
        }
        if (!userData['isAdmin']) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Accès réservé aux administrateurs')),
            );
            Navigator.pushReplacementNamed(context, '/');
          });
          return const HomeWrapper();
        }
        return const AdminPanel();
      },
    );
  }

  Future<Map<String, dynamic>> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final roles = prefs.getStringList('userRoles') ?? [];
    return {
      'isLoggedIn': token != null && token.isNotEmpty,
      'isAdmin': roles.contains('ROLE_ADMIN'),
    };
  }
}

Future<int?> _getUserIdFromPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('userId');
}
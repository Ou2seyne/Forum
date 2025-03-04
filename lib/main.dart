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
        '/': (context) => const HomeWrapper(), // Always start with HomeWrapper
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/admin': (context) => const AdminPanel(),
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
        final userId = snapshot.data; // userId can be null if not logged in
        // Always show HomeScreen, passing userId (null if not logged in)
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
        // Require login for profile, redirect to LoginScreen if not logged in
        return userId != null
            ? ProfileScreen(userId: userId)
            : const LoginScreen();
      },
    );
  }
}

Future<int?> _getUserIdFromPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('userId');
}
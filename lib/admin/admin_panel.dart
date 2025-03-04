import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_themes.dart'; // Assuming this contains spacing and color constants

const String _baseApiUrl = 'https://s3-4662.nuage-peda.fr/forum2/api';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  List<dynamic> users = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int? userId;
  String? userRole;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    _glowAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );
    _animationController.forward();
    _loadUsers();
    _getUserDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final response = await http.get(
        Uri.parse('$_baseApiUrl/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          users = data['hydra:member'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Erreur: ${e.toString()}');
    }
  }

  Future<void> _toggleUserBlockStatus(int userId, bool isBlocked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (userRole != 'ROLE_ADMIN') {
        _showSnackBar('Seuls les administrateurs peuvent bloquer/débloquer des utilisateurs');
        return;
      }

      final endpoint = isBlocked ? 'unblock' : 'block';
      final url = '$_baseApiUrl/users/$userId/$endpoint';
      final response = await http.patch(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          final index = users.indexWhere((u) => u['id'] == userId);
          if (index != -1) {
            users[index]['isBlocked'] = !isBlocked;
          }
        });
        _showSnackBar(isBlocked ? 'Utilisateur débloqué' : 'Utilisateur bloqué', isSuccess: true);
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar('Erreur: ${errorData['message'] ?? 'Erreur inconnue'}');
      }
    } catch (e) {
      _showSnackBar('Erreur lors de la mise à jour du statut');
    }
  }

  Future<void> _getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    final roles = prefs.getStringList('userRoles');

    if (id != null && roles != null) {
      setState(() {
        userId = id;
        userRole = roles.isNotEmpty ? roles.first : 'Aucun rôle attribué';
      });
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isSuccess ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [darkBackgroundColor, secondaryColor.withOpacity(0.8)]
                : [backgroundColor, primaryColor.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(spacingL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    theme.primaryColor.withOpacity(0.5),
                                    theme.primaryColor,
                                  ],
                                  center: Alignment.center,
                                  radius: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.4),
                                    blurRadius: _glowAnimation.value,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                size: 30,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: spacingM),
                        Text(
                          "Panel Admin",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: theme.primaryColor.withOpacity(0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 26),
                          color: theme.primaryColor,
                          onPressed: _loadUsers,
                        ),
                        IconButton(
                          icon: const Icon(Icons.home, size: 26),
                          color: theme.primaryColor,
                          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                        ),
                      )
                    : SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: userId != null && userRole != null
                              ? ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(spacingM),
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    return _UserListItem(
                                      user: user,
                                      onBlockToggle: (isBlocked) => _toggleUserBlockStatus(user['id'], isBlocked),
                                    );
                                  },
                                )
                              : const Center(
                                  child: Text(
                                    'Veuillez vous connecter en tant qu’admin',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final dynamic user;
  final Function(bool) onBlockToggle;

  const _UserListItem({
    required this.user,
    required this.onBlockToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isBlocked = user['isBlocked'] ?? false;
    final username = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
    final email = user['email'] ?? 'Pas d’email';
    final initials = username.isNotEmpty
        ? '${username.split(' ')[0][0]}${username.split(' ').length > 1 ? username.split(' ')[1][0] : ''}'
        : '??';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: spacingS),
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(spacingM),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.primaryColor.withOpacity(0.5),
                    theme.primaryColor,
                  ],
                  center: Alignment.center,
                  radius: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Text(
                  initials.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.isEmpty ? 'Utilisateur anonyme' : username,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: spacingXS),
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(color: accentColor),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isBlocked ? Icons.lock : Icons.lock_open,
                color: isBlocked ? Colors.red : Colors.green,
              ),
              onPressed: () => onBlockToggle(isBlocked),
              tooltip: isBlocked ? 'Débloquer' : 'Bloquer',
            ),
          ],
        ),
      ),
    );
  }
}
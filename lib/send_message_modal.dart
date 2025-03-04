import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_themes.dart'; // Assuming this contains your spacing and color constants

const Color twitterBlue = Color(0xFF1DA1F2);

class SendMessageModal extends StatefulWidget {
  final Function refreshMessages;
  final int? parentId; // For parent message when replying

  const SendMessageModal({
    super.key,
    required this.refreshMessages,
    this.parentId,
  });

  @override
  _SendMessageModalState createState() => _SendMessageModalState();
}

class _SendMessageModalState extends State<SendMessageModal> with SingleTickerProviderStateMixin {
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _contenuController = TextEditingController();
  bool _isLoading = false;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titreController.dispose();
    _contenuController.dispose();
    super.dispose();
  }

  Future<bool> _checkUserBlockedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');

    if (userId == null) return false;

    final response = await http.get(
      Uri.parse('https://s3-4662.nuage-peda.fr/forum2/api/users/$userId'),
      headers: {
        'Authorization': 'Bearer ${prefs.getString('token') ?? ''}',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['isBlocked'] ?? false;
    } else {
      return false;
    }
  }

  Future<void> sendMessage(String titre, String contenu) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final int? userId = prefs.getInt('userId');

    if (token == null || userId == null) {
      _showSnackBar("Erreur : utilisateur non authentifié.");
      return;
    }

    bool isBlocked = await _checkUserBlockedStatus();
    if (isBlocked) {
      _showSnackBar("Votre compte est bloqué. Vous ne pouvez pas envoyer de message.");
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> messageData = {
      'titre': titre,
      'datePoste': DateTime.now().toIso8601String(),
      'contenu': contenu,
      'user': '/forum2/api/users/$userId',
      'messages': [],
      'isDeleted': false,
      if (widget.parentId != null) 'parent': '/forum2/api/messages/${widget.parentId}',
    };

    try {
      final response = await http.post(
        Uri.parse('https://s3-4662.nuage-peda.fr/forum2/api/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(messageData),
      );

      if (response.statusCode == 201) {
        _showSnackBar("Message envoyé avec succès !", isSuccess: true);
        widget.refreshMessages();
        Navigator.pop(context);
      } else {
        _showSnackBar("Échec de l'envoi : ${response.body}");
      }
    } catch (e) {
      _showSnackBar("Erreur réseau : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [darkBackgroundColor, secondaryColor.withOpacity(0.8)]
              : [backgroundColor, twitterBlue.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // Rounded top corners
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(spacingL),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle for bottom sheet
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: spacingM),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Hero(
                  tag: 'sendMessageLogo',
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 100,
                        height: 100,
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
                          Icons.message,
                          size: 50,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: spacingXL),
                Text(
                  widget.parentId == null ? "Nouveau Message" : "Répondre",
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
                const SizedBox(height: spacingXL),
                Form(
                  child: Column(
                    children: [
                      if (widget.parentId == null)
                        _buildTextField(
                          controller: _titreController,
                          label: "Titre",
                          icon: Icons.title,
                          validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un titre' : null,
                          enabled: !_isLoading,
                        ),
                      if (widget.parentId == null) const SizedBox(height: spacingM),
                      _buildTextField(
                        controller: _contenuController,
                        label: "Contenu",
                        icon: Icons.text_fields,
                        maxLines: 5,
                        validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer du contenu' : null,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: spacingL),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => sendMessage(_titreController.text, _contenuController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: spacingM),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 8,
                            shadowColor: theme.primaryColor.withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Envoyer",
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimary,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(width: spacingS),
                                    Icon(Icons.send, size: 20, color: theme.colorScheme.onPrimary),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: spacingM),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Annuler",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      shadows: [
                        Shadow(
                          color: theme.primaryColor.withOpacity(0.3),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.primaryColor.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: theme.primaryColor),
        filled: true,
        fillColor: isDarkMode ? Colors.grey[900]!.withOpacity(0.8) : Colors.grey[100]!.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: spacingM, horizontal: spacingL),
      ),
      style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 16),
      validator: validator,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_themes.dart'; // Contains primaryColor, spacing constants, etc.

const String _baseApiUrl = 'https://s3-4662.nuage-peda.fr/forum2/api';

class MessageDetailsModal extends StatefulWidget {
  final int messageId;
  final VoidCallback? onDelete;
  final Function(int, String, String)? onEdit;
  final VoidCallback? onRefresh;

  const MessageDetailsModal({
    super.key,
    required this.messageId,
    this.onDelete,
    this.onEdit,
    this.onRefresh,
  });

  @override
  _MessageDetailsModalState createState() => _MessageDetailsModalState();
}

class _MessageDetailsModalState extends State<MessageDetailsModal> with SingleTickerProviderStateMixin {
  dynamic messageDetails;
  bool isLoading = true;
  bool hasError = false;
  final TextEditingController replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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
    _loadMessageDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessageDetails() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseApiUrl/messages/${widget.messageId}?embed=messages"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            messageDetails = data;
            isLoading = false;
          });
        } else {
          throw Exception("Invalid response format");
        }
      } else {
        throw Exception("Failed to load message: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
      debugPrint("Error loading message details: $e");
    }
  }

  Future<void> _sendReply() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isBlocked = prefs.getBool('isBlocked') ?? false;

      if (isBlocked) {
        _showErrorSnackbar('Votre compte est bloqué et ne peut pas envoyer de messages');
        return;
      }

      final token = prefs.getString('token');
      final userId = prefs.getInt('userId');

      if (token == null || userId == null) {
        _showLoginPrompt();
        return;
      }

      final replyText = replyController.text.trim();
      if (replyText.isEmpty) {
        _showErrorSnackbar('Veuillez écrire une réponse', Colors.orange);
        return;
      }

      final response = await http.post(
        Uri.parse("$_baseApiUrl/messages"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'titre': 'Reply',
          'contenu': replyText,
          'datePoste': DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now()),
          'user': 'api/users/$userId',
          'parent': '/api/messages/${widget.messageId}',
        }),
      );

      if (response.statusCode == 201) {
        replyController.clear();
        _showErrorSnackbar("Réponse envoyée avec succès !", Colors.green);
        widget.onRefresh?.call(); // Refresh parent screen
        _loadMessageDetails();
      } else {
        throw Exception("Échec de l'envoi: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      _showErrorSnackbar('Erreur: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _showErrorSnackbar(String message, [Color backgroundColor = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 10,
      ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(
          "Connexion requise",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        content: Text(
          "Vous devez être connecté pour répondre.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            child: Text(
              "Se connecter",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).primaryColor),
            ),
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
          TextButton(
            child: Text(
              "Annuler",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showEditPrompt() {
    if (messageDetails == null) return;

    final TextEditingController titleController = TextEditingController(text: messageDetails["titre"] ?? "");
    final TextEditingController contentController = TextEditingController(text: messageDetails["contenu"] ?? "");
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [darkBackgroundColor, secondaryColor.withOpacity(0.8)]
                    : [backgroundColor, primaryColor.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(spacingL),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 80,
                          height: 80,
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
                            Icons.edit,
                            size: 40,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: spacingXL),
                    Text(
                      "Modifier le message",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 24,
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
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: "Titre",
                        labelStyle: TextStyle(color: theme.primaryColor.withOpacity(0.8)),
                        prefixIcon: Icon(Icons.title, color: theme.primaryColor),
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
                      validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un titre' : null,
                    ),
                    const SizedBox(height: spacingM),
                    TextFormField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: "Contenu",
                        labelStyle: TextStyle(color: theme.primaryColor.withOpacity(0.8)),
                        prefixIcon: Icon(Icons.text_fields, color: theme.primaryColor),
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
                      validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer du contenu' : null,
                    ),
                    const SizedBox(height: spacingL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              widget.onEdit?.call(widget.messageId, titleController.text, contentController.text);
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingM),
                            elevation: 8,
                            shadowColor: Colors.green.withOpacity(0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(width: spacingS),
                              Icon(Icons.save, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(width: spacingM),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: spacingM),
          Text("Erreur de chargement", style: theme.textTheme.bodyMedium),
          const SizedBox(height: spacingM),
          ElevatedButton(
            onPressed: _loadMessageDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingM),
              elevation: 8,
              shadowColor: theme.primaryColor.withOpacity(0.5),
            ),
            child: const Text("Réessayer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _getUserInitials(dynamic userData) {
    if (userData is Map<String, dynamic>) {
      final prenom = userData["prenom"]?.toString() ?? "";
      final nom = userData["nom"]?.toString() ?? "";
      return "${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}".toUpperCase();
    }
    return "??";
  }

  String _getUserName(dynamic userData) {
    if (userData is Map<String, dynamic>) {
      final prenom = userData["prenom"]?.toString() ?? "";
      final nom = userData["nom"]?.toString() ?? "";
      return "$prenom $nom".trim();
    }
    return "Unknown User";
  }

  Widget _buildMainMessage(ThemeData theme) {
    if (messageDetails == null) return const SizedBox.shrink();

    final userData = messageDetails["user"];
    final datePoste = messageDetails["datePoste"]?.toString();
    final titre = messageDetails["titre"]?.toString() ?? "Sans titre";
    final contenu = messageDetails["contenu"]?.toString() ?? "Aucun contenu";

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.cardTheme.color,
      margin: const EdgeInsets.symmetric(vertical: spacingS),
      child: Padding(
        padding: const EdgeInsets.all(spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      _getUserInitials(userData),
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
                        _getUserName(userData),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (datePoste != null)
                        Text(
                          DateFormat('dd MMM yyyy • HH:mm').format(DateTime.parse(datePoste)),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: spacingL),
            Text(
              titre,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: spacingM),
            Text(
              contenu,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyItem(dynamic reply, ThemeData theme) {
    final userData = reply["user"];
    final datePoste = reply["datePoste"]?.toString();
    final contenu = reply["contenu"]?.toString() ?? "Aucun contenu";

    DateTime? parsedDate;
    if (datePoste != null) {
      try {
        parsedDate = DateTime.parse(datePoste);
      } catch (_) {
        parsedDate = DateTime.now();
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.cardTheme.color?.withOpacity(0.9),
      margin: const EdgeInsets.symmetric(vertical: spacingS),
      child: Padding(
        padding: const EdgeInsets.all(spacingM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
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
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Text(
                  _getUserInitials(userData),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getUserName(userData),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (parsedDate != null)
                        Text(
                          DateFormat('HH:mm').format(parsedDate),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: spacingS),
                  Text(
                    contenu,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              : [backgroundColor, primaryColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // Rounded top corners
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle for bottom sheet
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: spacingM, bottom: spacingM),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(spacingL),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                        ),
                      ),
                    )
                  : hasError
                      ? SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildErrorState(theme),
                          ),
                        )
                      : Column(
                          children: [
                            SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Column(
                                  children: [
                                    const SizedBox(height: spacingS),
                                    AnimatedBuilder(
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
                                            Icons.forum,
                                            size: 50,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: spacingXL),
                                    Text(
                                      "Discussion",
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
                                    Padding(
                                      padding: const EdgeInsets.all(spacingM),
                                      child: _buildMainMessage(theme),
                                    ),
                                    const SizedBox(height: spacingL),
                                    if (messageDetails["messages"] is List)
                                      Padding(
                                        padding: const EdgeInsets.all(spacingM),
                                        child: Column(
                                          children: (messageDetails["messages"] as List)
                                              .whereType<Map<String, dynamic>>()
                                              .map((reply) => _buildReplyItem(reply, theme))
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(spacingM),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: replyController,
                                          decoration: InputDecoration(
                                            hintText: 'Écrire une réponse...',
                                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                              color: accentColor,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: isDarkMode ? Colors.grey[900]! : Colors.grey[100]!,
                                            contentPadding: const EdgeInsets.symmetric(
                                              vertical: spacingM,
                                              horizontal: spacingL,
                                            ),
                                          ),
                                          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                          maxLines: 3,
                                        ),
                                      ),
                                      const SizedBox(width: spacingS),
                                      ElevatedButton(
                                        onPressed: _sendReply,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.primaryColor,
                                          foregroundColor: theme.colorScheme.onPrimary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                          padding: const EdgeInsets.all(spacingM),
                                          elevation: 8,
                                          shadowColor: theme.primaryColor.withOpacity(0.5),
                                        ),
                                        child: const Icon(Icons.send, size: 20),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: spacingM),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (widget.onEdit != null)
                                        ElevatedButton.icon(
                                          onPressed: _showEditPrompt,
                                          icon: const Icon(Icons.edit, size: 20),
                                          label: const Text("Modifier"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                            padding:
                                                const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingM),
                                            elevation: 8,
                                            shadowColor: Colors.green.withOpacity(0.5),
                                          ),
                                        ),
                                      if (widget.onEdit != null && widget.onDelete != null) const SizedBox(width: spacingM),
                                      if (widget.onDelete != null)
                                        ElevatedButton.icon(
                                          onPressed: widget.onDelete,
                                          icon: const Icon(Icons.delete, size: 20),
                                          label: const Text("Supprimer"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                            padding:
                                                const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingM),
                                            elevation: 8,
                                            shadowColor: Colors.red.withOpacity(0.5),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: spacingM),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      "Fermer",
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
                          ],
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
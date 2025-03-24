import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'message_details_modal.dart';
import 'send_message_modal.dart';
import 'theme_provider.dart';
import 'app_themes.dart';

// API Configuration
const String _baseApiUrl = 'https://s3-4662.nuage-peda.fr/forum2/api';

// Enhanced text styles
final TextStyle headlineStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  letterSpacing: -0.5,
  color: primaryColor,
);

final TextStyle titleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
);

final TextStyle bodyStyle = TextStyle(
  fontSize: 16,
  letterSpacing: 0.1,
  height: 1.4,
);

final TextStyle captionStyle = TextStyle(
  fontSize: 14,
  color: accentColor,
  letterSpacing: 0.2,
);

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  final int? userId;

  const HomeScreen({super.key, required this.userId});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, SingleTickerProviderStateMixin {
  Map<String, dynamic> categorizedMessages = {}; // {categoryName: {subCategoryName: [messages]}}
  List<dynamic> allMessages = [];
  bool isLoading = true;
  bool isLoggedIn = false;
  bool isAdmin = false;
  SharedPreferences? _prefs;
  int? currentUserId;
  bool isDarkMode = false;
  Timer? _debounce;
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
    _initPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getInt('userId');
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _checkLoginStatus();
    if (isLoggedIn) {
      await _loadCurrentUserId();
      await loadMessages();
    } else {
      _redirectToLogin();
    }
    _checkDarkMode();
  }

  void _checkLoginStatus() async {
    final token = _prefs?.getString('token');
    final roles = _prefs?.getStringList('userRoles') ?? [];
    setState(() {
      isLoggedIn = token != null && token.isNotEmpty;
      isAdmin = roles.contains("ROLE_ADMIN");
    });
  }

  void _checkDarkMode() async {
    setState(() {
      isDarkMode = _prefs?.getBool('isDarkMode') ?? false;
    });
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  Future<void> loadMessages() async {
    try {
      setState(() => isLoading = true);

      final token = _prefs?.getString('token');
      if (token == null || token.isEmpty) {
        throw Exception('No valid authentication token found');
      }

      // Fetch categories
      final categoriesResponse = await http.get(
        Uri.parse('$_baseApiUrl/categories'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (categoriesResponse.statusCode != 200) {
        throw Exception('Failed to load categories: ${categoriesResponse.body}');
      }
      final categoriesData = json.decode(categoriesResponse.body);
      final List<dynamic> categories = categoriesData['hydra:member'];

      // Log categories
      debugPrint('Fetched Categories: $categories');

      // Fetch all messages
      List<dynamic> allMessagesTemp = [];
      String url = "$_baseApiUrl/messages";
      bool hasMore = true;

      while (hasMore) {
        final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          List<dynamic> msgs = data["hydra:member"] ?? [];

          msgs = msgs.map((msg) {
            msg["id"] = int.parse(msg["id"].toString());
            msg["datePoste"] = msg["datePoste"]?.toString();
            msg["dateModification"] = msg["dateModification"]?.toString();

            // Handle user field
            if (msg["user"] is Map<String, dynamic>) {
              msg["userId"] = int.tryParse(msg["user"]["@id"]?.toString().split('/').last ?? '');
            } else if (msg["user"] is String) {
              msg["userId"] = int.tryParse(msg["user"].toString().split('/').last);
            }

            // Handle parent field
            if (msg["parent"] is String) {
              msg["parentId"] = int.tryParse(msg["parent"].toString().split('/').last);
            } else if (msg["parent"] is Map<String, dynamic>) {
              msg["parentId"] = int.tryParse(msg["parent"]["@id"]?.toString().split('/').last ?? '');
            } else {
              msg["parentId"] = null;
            }

            // Handle category field
            if (msg["category"] is String) {
              msg["categoryId"] = msg["category"].toString().extractIdFromIri();
            } else if (msg["category"] is Map<String, dynamic>) {
              msg["categoryId"] = msg["category"]["id"];
            } else {
              msg["categoryId"] = null;
            }

            // Handle subCategory field
            if (msg["subCategory"] is String) {
              msg["subCategoryId"] = msg["subCategory"].toString().extractIdFromIri();
            } else if (msg["subCategory"] is Map<String, dynamic>) {
              msg["subCategoryId"] = msg["subCategory"]["id"];
            } else {
              msg["subCategoryId"] = null;
            }

            // Log the extracted IDs for debugging
            debugPrint('Message ID: ${msg["id"]}, Category ID: ${msg["categoryId"]}, SubCategory ID: ${msg["subCategoryId"]}');

            return msg;
          }).toList();

          allMessagesTemp.addAll(msgs);
          hasMore = data["hydra:next"] != null;
          if (hasMore) {
            url = data["hydra:next"];
          }
        } else {
          throw Exception('Failed to load messages: ${response.body}');
        }
      }

      // Filter parent messages and calculate reply counts
      final parentMessages = allMessagesTemp.where((msg) => msg["parentId"] == null).toList();
      for (var parent in parentMessages) {
        parent["replyCount"] = allMessagesTemp.where((msg) => msg["parentId"] == parent["id"]).length;
      }

      // Group messages by category and subcategory
      Map<String, dynamic> tempCategorizedMessages = {};
      for (var category in categories) {
        final categoryId = category['id'];
        final categoryName = category['name'];
        tempCategorizedMessages[categoryName] = {};

        // Fetch subcategories for this category
        final subCategoriesResponse = await http.get(
          Uri.parse('$_baseApiUrl/categories/$categoryId/subcategories'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (subCategoriesResponse.statusCode == 200) {
          final subCategories = json.decode(subCategoriesResponse.body);
          // Log subcategories
          debugPrint('Fetched SubCategories for Category $categoryName: $subCategories');

          for (var subCategory in subCategories) {
            final subCategoryId = subCategory['id'];
            final subCategoryName = subCategory['name'];
            final categoryMessages = parentMessages
                .where((msg) => msg["categoryId"] == categoryId && msg["subCategoryId"] == subCategoryId)
                .toList();
            categoryMessages.sort((a, b) => DateTime.parse(b["datePoste"]).compareTo(DateTime.parse(a["datePoste"])));
            tempCategorizedMessages[categoryName][subCategoryName] = categoryMessages;
          }
        }

        // Handle messages without subcategories
        final uncategorizedMessages = parentMessages
            .where((msg) => msg["categoryId"] == categoryId && msg["subCategoryId"] == null)
            .toList();
        uncategorizedMessages.sort((a, b) => DateTime.parse(b["datePoste"]).compareTo(DateTime.parse(a["datePoste"])));
        if (uncategorizedMessages.isNotEmpty) {
          tempCategorizedMessages[categoryName]['Sans sous-catégorie'] = uncategorizedMessages;
        }
      }

      // Handle uncategorized messages
      final uncategorized = parentMessages.where((msg) => msg["categoryId"] == null).toList();
      uncategorized.sort((a, b) => DateTime.parse(b["datePoste"]).compareTo(DateTime.parse(a["datePoste"])));
      if (uncategorized.isNotEmpty) {
        tempCategorizedMessages['Sans catégorie'] = {'Sans sous-catégorie': uncategorized};
      }

      // Log the final categorized messages
      debugPrint('Categorized Messages: $tempCategorizedMessages');

      setState(() {
        allMessages = allMessagesTemp;
        categorizedMessages = tempCategorizedMessages;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackbar('Erreur lors du chargement des messages: $e');
      _redirectToLogin();
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

  void _openSendMessageModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SendMessageModal(refreshMessages: _refreshMessages),
    );
  }

  void _refreshMessages() {
    loadMessages();
  }

  Future<void> deleteMessage(int messageId, int? authorId) async {
    if (!isLoggedIn) {
      _showErrorSnackbar('Vous devez être connecté pour effectuer cette action');
      return;
    }

    if (authorId == null) {
      _showErrorSnackbar("Impossible de déterminer l'auteur du message");
      return;
    }

    if (currentUserId != authorId && !isAdmin) {
      _showErrorSnackbar("Seul l'auteur ou un administrateur peut supprimer ce message");
      return;
    }

    try {
      final token = _prefs?.getString('token');
      final response = await http.delete(
        Uri.parse('$_baseApiUrl/messages/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() {
          categorizedMessages.forEach((category, subCategories) {
            subCategories.forEach((subCategory, messages) {
              messages.removeWhere((msg) => msg["id"] == messageId);
            });
          });
        });
        _showErrorSnackbar("Message supprimé avec succès", Colors.green);
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de la suppression du message");
    }
  }

  Future<void> updateMessage(int messageId, String titre, String contenu, String userIri) async {
    if (!isLoggedIn) {
      _showErrorSnackbar('Vous devez être connecté pour effectuer cette action');
      return;
    }

    try {
      final token = _prefs?.getString('token');
      final response = await http.put(
        Uri.parse('$_baseApiUrl/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/ld+json',
        },
        body: jsonEncode({
          'titre': titre,
          'contenu': contenu,
          'user': userIri,
          'dateModification': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final updatedMessage = jsonDecode(response.body);
        setState(() {
          categorizedMessages.forEach((category, subCategories) {
            subCategories.forEach((subCategory, messages) {
              final index = messages.indexWhere((msg) => msg["id"] == messageId);
              if (index != -1) {
                messages[index] = {
                  ...messages[index],
                  'titre': titre,
                  'contenu': contenu,
                  'dateModification': updatedMessage['dateModification'],
                };
              }
            });
          });
        });
        _showErrorSnackbar('Message mis à jour avec succès', Colors.green);
      }
    } catch (e) {
      _showErrorSnackbar('Erreur lors de la mise à jour du message');
    }
  }

  void _logout() async {
    if (_prefs != null) {
      await _prefs!.remove('token');
      await _prefs!.remove('userId');
      await _prefs!.remove('userRoles');
      setState(() {
        isLoggedIn = false;
        isAdmin = false;
      });
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void toggleTheme() {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
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
                                Icons.forum,
                                size: 30,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: spacingM),
                        Text(
                          "Forum",
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
                   SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        icon: const Icon(Icons.search, size: 26),
        color: Theme.of(context).primaryColor,
        onPressed: () => showSearch(context: context, delegate: MessageSearchDelegate(allMessages: allMessages)),
      ),
      if (isLoggedIn) ...[
        IconButton(
          icon: const Icon(Icons.person, size: 26),
          color: Theme.of(context).primaryColor,
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, size: 26),
            color: Theme.of(context).primaryColor,
            tooltip: 'Admin Panel',
            onPressed: () => Navigator.pushNamed(context, '/admin'),
          ),
        IconButton(
          icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, size: 26),
          color: Theme.of(context).primaryColor,
          onPressed: () => toggleTheme(),
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 26),
          color: Theme.of(context).primaryColor,
          onPressed: () => _logout(),
        ),
      ] else ...[
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          child: const Text("Connexion"),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text("Inscription"),
        ),
      ],
    ],
  ),
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
                    : RefreshIndicator(
                        color: theme.primaryColor,
                        onRefresh: loadMessages,
                        child: categorizedMessages.isEmpty
                            ? SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.message, size: 48, color: theme.primaryColor.withOpacity(0.5)),
                                        const SizedBox(height: spacingM),
                                        Text(
                                          'Aucun message disponible',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(spacingM),
                                itemCount: categorizedMessages.keys.length,
                                itemBuilder: (context, index) {
                                  final categoryName = categorizedMessages.keys.elementAt(index);
                                  final subCategories = categorizedMessages[categoryName];
                                  return ExpansionTile(
                                    leading: Icon(Icons.category, color: theme.primaryColor),
                                    title: Text(
                                      categoryName,
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    children: subCategories.keys.map<Widget>((subCategoryName) {
                                      final messages = subCategories[subCategoryName];
                                      return ExpansionTile(
                                        leading: Icon(Icons.subdirectory_arrow_right, color: theme.primaryColor),
                                        title: Text(
                                          subCategoryName,
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        children: messages.isEmpty
                                            ? [
                                                Padding(
                                                  padding: const EdgeInsets.all(spacingM),
                                                  child: Text(
                                                    'Aucun message dans cette sous-catégorie',
                                                    style: theme.textTheme.bodyMedium,
                                                  ),
                                                ),
                                              ]
                                            : messages.map<Widget>((message) {
                                                return SlideTransition(
                                                  position: _slideAnimation,
                                                  child: FadeTransition(
                                                    opacity: _fadeAnimation,
                                                    child: _buildMessageCard(message, theme),
                                                  ),
                                                );
                                              }).toList(),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                      ),
              ),
              if (isLoggedIn)
                Padding(
                  padding: const EdgeInsets.all(spacingM),
                  child: ElevatedButton(
                    onPressed: _openSendMessageModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingM),
                      elevation: 8,
                      shadowColor: theme.primaryColor.withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.create, size: 20),
                        const SizedBox(width: spacingS),
                        Text(
                          "Nouveau message",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(dynamic message, ThemeData theme) {
    final datePoste = DateTime.tryParse(message["datePoste"] ?? "") ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy • HH:mm').format(datePoste);
    final dynamic userData = message["user"];
    final isModified = message["dateModification"] != null && message["dateModification"].isNotEmpty;

    String displayName = "Anonyme";
    if (userData is Map<String, dynamic>) {
      displayName = userData["prenom"] != null && userData["nom"] != null
          ? "${userData["prenom"]} ${userData["nom"]}"
          : "Utilisateur";
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: spacingS),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showMessageDetails(message),
        child: Padding(
          padding: const EdgeInsets.all(spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(userData, displayName, theme),
                  const SizedBox(width: spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessageHeader(displayName, formattedDate, theme),
                        const SizedBox(height: spacingS),
                        _buildMessageContent(message, theme),
                        if (isModified) _buildModifiedBadge(theme),
                        const SizedBox(height: spacingS),
                        _buildMessageFooter(message, theme),
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

  Widget _buildAvatar(dynamic userData, String displayName, ThemeData theme) {
    return Container(
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
        backgroundImage: userData is Map<String, dynamic> && userData["profilePicture"] != null
            ? NetworkImage(userData["profilePicture"])
            : null,
        child: userData is Map<String, dynamic> && userData["profilePicture"] == null
            ? Text(
                displayName[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildMessageHeader(String displayName, String formattedDate, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            displayName,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          formattedDate,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMessageContent(dynamic message, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message["titre"] ?? "",
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: spacingS),
        Text(
          truncateText(message["contenu"] ?? "", 140),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  Widget _buildModifiedBadge(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: spacingS),
      padding: const EdgeInsets.symmetric(horizontal: spacingS, vertical: spacingXS),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        'Modifié',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageFooter(dynamic message, ThemeData theme) {
    final repliesCount = message["replyCount"] ?? 0;

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showMessageDetails(message),
            child: Padding(
              padding: const EdgeInsets.all(spacingXS),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: spacingXS),
                  Text(
                    '$repliesCount réponse${repliesCount != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMessageDetails(dynamic message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageDetailsModal(
        messageId: message["id"],
        onDelete: () async {
          await deleteMessage(int.parse(message["id"].toString()), message["userId"]);
        },
        onEdit: (int messageId, String titre, String contenu) async {
          final userIri =
              message["user"] is Map<String, dynamic> ? message["user"]["@id"] : message["user"].toString();
          await updateMessage(messageId, titre, contenu, userIri);
          _refreshMessages();
        },
        onRefresh: _refreshMessages,
      ),
    );
  }
}

class MessageSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> allMessages;

  MessageSearchDelegate({required this.allMessages});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(vertical: spacingM, horizontal: spacingL),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final List<dynamic> searchResults = allMessages.where((msg) {
      final titre = (msg["titre"] ?? "").toString().toLowerCase();
      final contenu = (msg["contenu"] ?? "").toString().toLowerCase();
      final searchQuery = query.toLowerCase();
      return titre.contains(searchQuery) || contenu.contains(searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(spacingM),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final message = searchResults[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(vertical: spacingS),
          child: ListTile(
            contentPadding: const EdgeInsets.all(spacingM),
            title: Text(
              message["titre"] ?? "Sans titre",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              truncateText(message["contenu"] ?? "", 100),
              style: theme.textTheme.bodyMedium?.copyWith(color: accentColor),
            ),
            onTap: () {
              close(context, message["titre"] ?? "");
            },
          ),
        );
      },
    );
  }
}

String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, text.lastIndexOf(' ', maxLength))}...';
}

extension StringExtension on String {
  int? extractIdFromIri() {
    final uri = Uri.parse(this);
    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      return int.tryParse(segments.last);
    }
    return null;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_themes.dart';
import 'package:image_picker/image_picker.dart';

const String _baseApiUrl = 'https://s3-4662.nuage-peda.fr/forum2/api';
const Color twitterBlue = Color(0xFF1DA1F2);

class ProfileScreen extends StatefulWidget {
  final int userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  String userFirstName = 'Inconnu';
  String userLastName = 'Inconnu';
  String userRoles = 'Aucun rôle';
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> messages = [];
  int? _currentUserId;
  List<String> _currentUserRoles = [];
  bool isDarkMode = false;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _glowAnimation;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();


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
    _loadCurrentUserData();
    _fetchUserData();
    _fetchUserMessages();
    _checkDarkMode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('userId');
      _currentUserRoles = prefs.getStringList('userRoles') ?? [];
      userRoles = _currentUserRoles.isEmpty ? 'Aucun rôle' : _currentUserRoles.join(', ');
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _checkDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = !isDarkMode;
      prefs.setBool('isDarkMode', isDarkMode);
    });
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      // Optionally, upload the image to the server
      _uploadProfilePicture(_profileImage!);
    }
  }

  Future<void> _uploadProfilePicture(File image) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Token d\'authentification manquant.';
      });
      return;
    }

    try {
      final uri = Uri.parse('$_baseApiUrl/users/${widget.userId}/profile_picture');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        setState(() {
          _errorMessage = 'Photo de profil mise à jour avec succès.';
        });
      } else {
        throw Exception('Échec de l\'upload de l\'image.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de téléchargement de l\'image: $e';
      });
    }
  }

  Future<void> _fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Token d\'authentification manquant.';
      });
      return;
    }

    try {
      final userResponse = await http.get(
        Uri.parse('$_baseApiUrl/users/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        setState(() {
          userFirstName = userData['prenom'] ?? 'Inconnu';
          userLastName = userData['nom'] ?? 'Inconnu';
          _currentUserRoles = (userData['roles'] as List<dynamic>?)?.map((role) => role.toString()).toList() ?? [];
          userRoles = _currentUserRoles.isEmpty ? 'Aucun rôle' : _currentUserRoles.join(', ');
          _isLoading = false;
          // Optionally load the profile image URL here
        });
      } else {
        throw Exception('Erreur utilisateur: ${userResponse.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Échec du chargement des données: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        _errorMessage = "Token d'authentification manquant.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseApiUrl/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/ld+json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> allMessages = data['hydra:member'] ?? [];

        setState(() {
          messages = allMessages.where((msg) {
            final user = msg["user"];
            if (user == null) return false;

            final userIri = user is String ? user : user["@id"];
            if (userIri == null) return false;

            final userIdFromIri = userIri.split('/').last;
            return userIdFromIri == widget.userId.toString();
          }).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Échec du chargement des messages: $e';
        _isLoading = false;
      });
    }
  }

  void editMessage(dynamic message) async {
    final TextEditingController titleController = TextEditingController(text: message["titre"] ?? "");
    final TextEditingController contentController = TextEditingController(text: message["contenu"] ?? "");
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
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
                              Navigator.pop(context, true);
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
                          onPressed: () => Navigator.pop(context, false),
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

    if (result == true) {
      updateMessage(message["id"], titleController.text, contentController.text);
    }
  }

  Future<void> updateMessage(int messageId, String titre, String contenu) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final int? currentUserId = prefs.getInt('userId');

    if (token == null || currentUserId == null) {
      debugPrint("Erreur : Token ou user_id manquant");
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> updateData = {
      'titre': titre,
      'contenu': contenu,
      'user': '/api/users/$currentUserId',
    };

    try {
      final response = await http.put(
        Uri.parse('$_baseApiUrl/messages/$messageId'),
        headers: {
          'Content-Type': 'application/ld+json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final updatedResponse = json.decode(response.body);
        final int index = messages.indexWhere((msg) => msg["id"] == messageId);
        if (index != -1) {
          if (updatedResponse["user"] is! Map) {
            updatedResponse["user"] = messages[index]["user"];
          }
          setState(() {
            messages[index] = updatedResponse;
          });
        }
        _showSnackBar("Message mis à jour avec succès", isSuccess: true);
      } else {
        _showSnackBar("Erreur lors de la mise à jour: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Erreur réseau: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce message ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() => _errorMessage = 'Authentification requise');
        return;
      }

      setState(() => _isLoading = true);

      final response = await http.delete(
        Uri.parse('$_baseApiUrl/messages/${message['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          messages.removeWhere((msg) => msg['id'] == message['id']);
          _errorMessage = '';
        });
        _showSnackBar("Message supprimé avec succès", isSuccess: true);
      } else {
        _showSnackBar('Erreur lors de la suppression: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Erreur: ${e is SocketException ? 'Vérifiez votre connexion' : e.toString()}');
    } finally {
      setState(() => _isLoading = false);
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('userRoles');
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildUserInfo() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [darkBackgroundColor, secondaryColor.withOpacity(0.8)]
              : [backgroundColor, primaryColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'profile-avatar-${widget.userId}',
            child: Container(
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
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Text(
                  '${userFirstName.isNotEmpty ? userFirstName[0] : ''}${userLastName.isNotEmpty ? userLastName[0] : ''}'
                      .toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$userFirstName $userLastName",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: spacingS),
                Wrap(
                  spacing: spacingS,
                  runSpacing: spacingS,
                  children: _currentUserRoles.map((role) {
                    Color badgeColor;
                    switch (role) {
                      case 'ROLE_ADMIN':
                        badgeColor = Colors.red.shade400;
                        break;
                      case 'ROLE_MOD':
                        badgeColor = Colors.orange.shade400;
                        break;
                      default:
                        badgeColor = Colors.blueGrey.shade300;
                    }
                    return Chip(
                      label: Text(role, style: const TextStyle(color: Colors.white)),
                      backgroundColor: badgeColor,
                      padding: const EdgeInsets.symmetric(horizontal: spacingS),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(dynamic message, int index) {
    final theme = Theme.of(context);
    DateTime date = DateTime.parse(message["datePoste"]);
    String formattedDate = DateFormat('dd MMM yyyy • HH:mm').format(date);

    String? messageUserIdStr;
    if (message['user'] != null && message['user']['@id'] != null) {
      messageUserIdStr = message['user']['@id'].split('/').last;
    }

    final messageUserId = int.tryParse(messageUserIdStr ?? '');
    bool canEditOrDelete = messageUserId != null &&
        (messageUserId == _currentUserId || _currentUserRoles.contains('ROLE_ADMIN'));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 100),
      builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(vertical: spacingS),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          splashColor: theme.primaryColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message["titre"] ?? "Titre indisponible",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: twitterBlue,
                  ),
                ),
                const SizedBox(height: spacingS),
                Text(
                  message["contenu"] ?? "Contenu indisponible",
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: spacingM),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: spacingXS),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (canEditOrDelete)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: theme.primaryColor),
                          onPressed: () => editMessage(message),
                          tooltip: 'Modifier',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteMessage(message),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Messages de l\'utilisateur',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: spacingM),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageCard(messages[index], index),
        ),
      ],
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
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              )
            : SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
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
                                      child: _profileImage != null
                                          ? ClipOval(
                                              child: Image.file(
                                                _profileImage!,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 30,
                                              color: Colors.white,
                                            ),
                                    );
                                  },
                                ),
                                const SizedBox(width: spacingM),
                                Text(
                                  "Profil",
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
                                  icon: Icon(
                                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                                    size: 26,
                                  ),
                                  color: theme.primaryColor,
                                  onPressed: _toggleDarkMode,
                                  tooltip: isDarkMode ? 'Mode clair' : 'Mode sombre',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, size: 26),
                                  color: theme.primaryColor,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(spacingL),
                          child: Column(
                            children: [
                              _buildUserInfo(),
                              const SizedBox(height: spacingXL),
                              if (_errorMessage.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(spacingM),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: spacingXL),
                              _buildMessagesList(),
                              const SizedBox(height: spacingL),
                              // Button to change profile picture
                              ElevatedButton(
                                onPressed: _pickImage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingM),
                                  elevation: 8,
                                  shadowColor: theme.primaryColor.withOpacity(0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.camera_alt, size: 20),
                                    SizedBox(width: spacingS),
                                    Text(
                                      'Changer la photo de profil',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: spacingL),
                              ElevatedButton(
                                onPressed: _logout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingM),
                                  elevation: 8,
                                  shadowColor: Colors.red.withOpacity(0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.logout, size: 20),
                                    SizedBox(width: spacingS),
                                    Text(
                                      'Déconnexion',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
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
      ),
    ),
  );
}
}
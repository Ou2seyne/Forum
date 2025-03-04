import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_themes.dart'; // Assuming this exists from your LoginScreen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _showPassword = false;
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
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      _showErrorSnackbar("Veuillez remplir tous les champs correctement");
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final response = await http.post(
        Uri.parse("https://s3-4662.nuage-peda.fr/forum2/api/users"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'prenom': _prenomController.text,
          'nom': _nomController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 201) {
        // Optionally store token if your API returns one
        final result = json.decode(response.body);
        if (result['token'] != null) {
          await _storeUserData(result);
        }
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (Route<dynamic> route) => false,
        );
      } else {
        String errorMessage = "Erreur lors de l'inscription";
        final errorData = json.decode(response.body);
        if (errorData['violations'] != null) {
          for (var violation in errorData['violations']) {
            if (violation['propertyPath'] == 'email') {
              errorMessage = "Cet email est déjà pris";
            }
          }
        }
        _showErrorSnackbar(errorMessage);
      }
    } catch (e) {
      _showErrorSnackbar("Erreur de connexion: $e");
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _storeUserData(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', result['token']);
    // Add more user data if your API returns it
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.withOpacity(0.9),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(spacingL),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: 'registerLogo',
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
                                    color:
                                        theme.primaryColor.withOpacity(0.4),
                                    blurRadius: _glowAnimation.value,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add,
                                size: 50,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: spacingXL),
                      Text(
                        "Inscription",
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
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildNameFields(),
                            const SizedBox(height: spacingM),
                            _buildTextField(
                              controller: _emailController,
                              label: "Email",
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) => value == null || value.isEmpty
                                  ? 'Veuillez entrer votre email'
                                  : null,
                            ),
                            const SizedBox(height: spacingM),
                            _buildTextField(
                              controller: _passwordController,
                              label: "Mot de passe",
                              icon: Icons.lock,
                              obscureText: !_showPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: theme.primaryColor,
                                ),
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                              validator: (value) => value == null || value.isEmpty
                                  ? 'Veuillez entrer votre mot de passe'
                                  : null,
                            ),
                            const SizedBox(height: spacingL),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isRegistering ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: spacingM),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  elevation: 8,
                                  shadowColor:
                                      theme.primaryColor.withOpacity(0.5),
                                ),
                                child: _isRegistering
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<
                                                  Color>(
                                              theme.colorScheme.onPrimary),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "S'inscrire",
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(width: spacingS),
                                          Icon(Icons.arrow_forward,
                                              size: 20,
                                              color:
                                                  theme.colorScheme.onPrimary),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: spacingM),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/login'),
                        child: RichText(
                          text: TextSpan(
                            text: 'Déjà un compte ? ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                            children: [
                              TextSpan(
                                text: 'Connectez-vous',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                  shadows: [
                                    Shadow(
                                      color:
                                          theme.primaryColor.withOpacity(0.3),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: spacingS),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/'),
                        child: Text(
                          "Retour à l'accueil",
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
          ),
        ),
      ),
    );
  }

  Widget _buildNameFields() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _prenomController,
            label: "Prénom",
            icon: Icons.person,
            validator: (value) => value == null || value.isEmpty
                ? 'Veuillez entrer votre prénom'
                : null,
          ),
        ),
        const SizedBox(width: spacingM),
        Expanded(
          child: _buildTextField(
            controller: _nomController,
            label: "Nom",
            icon: Icons.person_outline,
            validator: (value) => value == null || value.isEmpty
                ? 'Veuillez entrer votre nom'
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.primaryColor.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: theme.primaryColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDarkMode
            ? Colors.grey[900]!.withOpacity(0.8)
            : Colors.grey[100]!.withOpacity(0.5),
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
        contentPadding:
            const EdgeInsets.symmetric(vertical: spacingM, horizontal: spacingL),
      ),
      style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 16),
      validator: validator,
    );
  }
}
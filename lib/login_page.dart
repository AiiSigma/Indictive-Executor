import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'splash.dart';

const String baseUrl = "http://127.0.0.1:3000";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _initAnim();
    initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
          "$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SplashScreen(
                username: savedUser,
                password: savedPass,
                role: data['role'],
                sessionKey: data['key'],
                expiredDate: data['expiredDate'],
                listBug: (data['listBug'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                listDoos: (data['listDoos'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
            ),
          );
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    final username = userController.text.trim();
    final password = passController.text.trim();

    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("$baseUrl/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
          "version": "6.0",
        },
      );

      final validData = jsonDecode(validate.body);
      if (validData['oldVer'] == true) {
        _showPopup(
          title: "Update Required",
          message: "Your client does not match.\nPlease update it.",
          color: Colors.orange,
          showContact: true,
        );
      } else if (validData['expired'] == true) {
        _showPopup(
          title: "⏳ Access Expired",
          message: "Your access has expired.\nPlease renew it.",
          color: Colors.orange,
          showContact: true,
        );
      } else if (validData['valid'] != true) {
        _showPopup(
          title: "❌ Login Failed",
          message: "Invalid username or password.",
          color: Colors.red,
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SplashScreen(
              username: username,
              password: password,
              role: validData['role'],
              sessionKey: validData['key'],
              expiredDate: validData['expiredDate'],
              listBug: (validData['listBug'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              listDoos: (validData['listDoos'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            ),
          ),
        );
      }
    } catch (e) {
      _showPopup(
        title: "⚠️ Connection Error",
        message: "Failed to connect to the server.\nPlease check your internet connection.",
        color: Colors.blueGrey,
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  void _showPopup({
    required String title,
    required String message,
    Color color = Colors.red,
    bool showContact = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          if (showContact)
            TextButton(
              onPressed: () async {
                _openUrl("https://t.me/KaiiOfficial");
              },
              child: const Text("Channel", style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputWidth = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF2B0000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: GlassContainer(
                  width: inputWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Hero(
                        tag: "logo",
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/logo.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.security_rounded,
                                color: Colors.white54,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text("Welcome Back",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Text("Sign in to continue",
                          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      const SizedBox(height: 24),

                      // Form Input
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _glassInput(
                              controller: userController,
                              label: "Username",
                              icon: Icons.person_outline,
                              validatorMsg: "Please enter your username.",
                            ),
                            const SizedBox(height: 16),
                            _glassInput(
                              controller: passController,
                              label: "Password",
                              icon: Icons.lock_outline,
                              isPassword: true,
                              validatorMsg: "Please enter your password.",
                            ),
                            const SizedBox(height: 25),

                            // Tombol login
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: isLoading ? 55 : inputWidth * 0.7,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.shade700.withOpacity(0.9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  shadowColor: Colors.redAccent,
                                  elevation: 10,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                                    : const Text("Sign In",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                              ),
                            ),
                          ],
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

  Widget _glassInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String validatorMsg,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white70),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent)),
      ),
      validator: (v) => v == null || v.isEmpty ? validatorMsg : null,
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;

  const GlassContainer({super.key, required this.child, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }
}

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BugPage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final String role;
  final String expiredDate;

  const BugPage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.listDoos,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<BugPage> createState() => _BugPageState();
}

class _BugPageState extends State<BugPage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  String selectedBugId = "";

  bool _isSending = false;
  String? _responseMessage;

  // --- PERUBAHAN TEMA WARNA ---
  // Wana tema diubah menjadi merah tua dan hitam
  final Color darkRed = const Color(0xFFB71C1C); // Merah tua utama
  final Color accentRed = const Color(0xFFFF5252); // Merah lebih terang untuk aksen
  final Color glassBlack = Colors.black.withOpacity(0.4); // Sedikit lebih gelap untuk kontras
  final Color panelBg   = const Color(0xFF000000);
  final Color borderRed = const Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.listBug.isNotEmpty) {
      selectedBugId = widget.listBug[0]['bug_id'];
    }

  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    targetController.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final target = formatPhoneNumber(rawInput);
    final key = widget.sessionKey;

    if (target == null || key.isEmpty) {
      _showAlert("❌ Invalid Number",
          "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
      return;
    }

    setState(() {
      _isSending = true;
      _responseMessage = null;
    });

    try {
      final res = await http.get(Uri.parse(
          "http://127.0.0.1:3000/sendBug?key=$key&target=$target&bug=$selectedBugId"));
      final data = jsonDecode(res.body);

      if (data["cooldown"] == true) {
        setState(() => _responseMessage = "⏳ Cooldown: Tunggu beberapa saat.");
      } else if (data["valid"] == false) {
        setState(() => _responseMessage = "❌ Key Invalid: Silakan login ulang.");
      } else if (data["sended"] == false) {
        setState(() => _responseMessage =
        "⚠️ Gagal: Server sedang maintenance.");
      } else {
        setState(() => _responseMessage = "✅ Berhasil mengirim bug ke $target!");
        targetController.clear();
      }
    } catch (_) {
      setState(() =>
      _responseMessage = "❌ Error: Terjadi kesalahan. Coba lagi.");
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: glassBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            // --- PERUBAHAN BORDER ---
            side: BorderSide(color: darkRed.withOpacity(0.3), width: 1.5),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              // --- PERUBAHAN GRADIENT ---
              colors: [darkRed, accentRed],
            ).createShader(bounds),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          content: Text(msg, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              // --- PERUBAHAN TEKS ---
              child: Text("OK", style: TextStyle(color: accentRed)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          // --- PERUBAHAN BAYANGAN ---
          BoxShadow(
            color: darkRed.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeaderPanel() {
  return SlideTransition(
    position: _slideAnimation,
    child: LayoutBuilder(
      builder: (context, c) {
        final double headerWidth = c.maxWidth * 0.60;

        return Center(
          child: Container(
            width: headerWidth,
            constraints: const BoxConstraints(maxWidth: 390),

            // ===== BORDER MERAH LUAR =====
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.red,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ],
            ),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  // ===== BASE CARD =====
                  Container(
  width: double.infinity, // ✅ FIX
  padding: const EdgeInsets.symmetric(vertical: 20),
  color: const Color(0xFF7C1F1F),
  child: Column(
    mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.45),
                          ),
                          child: const CircleAvatar(
                            radius: 34,
                            backgroundImage:
                                AssetImage('assets/images/logo.jpg'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.username,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Role: ${widget.role.toUpperCase()} • Exp: ${widget.expiredDate}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===== CENGKUNG ATAS & BAWAH =====
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.45),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.55),
                          ],
                          stops: const [0.0, 0.18, 0.82, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ===== CENGKUNG KIRI & KANAN =====
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity(0.45),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.45),
                          ],
                          stops: const [0.0, 0.18, 0.82, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ===== RIM DALAM (BIAR KELIATAN DALAM) =====
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.45),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildInputPanel() {
  return SlideTransition(
    position: _slideAnimation,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelBg, // HITAM SOLID
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderRed.withOpacity(0.85),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: borderRed.withOpacity(0.25),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== TARGET NUMBER =====
          const Text(
            "Target Number",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderRed.withOpacity(0.7),
              ),
            ),
            child: TextField(
              controller: targetController,
              cursorColor: borderRed,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "e.g. +62xxxxxxxxxx",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ===== SELECT BUG =====
          const Text(
            "Select Bug",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderRed.withOpacity(0.7),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedBugId,
                isExpanded: true,
                dropdownColor: Colors.black,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: borderRed,
                  size: 26,
                ),
                style: const TextStyle(color: Colors.white),
                items: widget.listBug.map((bug) {
                  return DropdownMenuItem<String>(
                    value: bug['bug_id'],
                    child: Text(
                      bug['bug_name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedBugId = value ?? "";
                  });
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSendButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // --- PERUBAHAN GRADIENT ---
              gradient: LinearGradient(
                colors: [
                  darkRed.withOpacity(0.8),
                  accentRed.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                // --- PERUBAHAN BAYANGAN ---
                BoxShadow(
                  color: darkRed.withOpacity(0.4 * _pulseController.value),
                  blurRadius: 25 * _pulseController.value,
                  spreadRadius: 3 * _pulseController.value,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendBug,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bug_report, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    "SEND BUG",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponseMessage() {
    if (_responseMessage == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _responseMessage!.startsWith('✅')
                ? [Colors.green.withOpacity(0.3), Colors.greenAccent.withOpacity(0.1)]
                : [Colors.red.withOpacity(0.3), Colors.redAccent.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _responseMessage!.startsWith('✅')
                ? Colors.greenAccent.withOpacity(0.5)
                : Colors.redAccent.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _responseMessage!.startsWith('✅') ? Icons.check_circle : Icons.error,
              color: _responseMessage!.startsWith('✅') ? Colors.greenAccent : Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _responseMessage!,
                style: TextStyle(
                  color: _responseMessage!.startsWith('✅') ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- PERUBAHAN BACKGROUND ---
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Effects
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  // --- PERUBAHAN GRADIENT ---
                  colors: [
                    darkRed.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  // --- PERUBAHAN GRADIENT ---
                  colors: [
                    accentRed.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeaderPanel(), // Sekarang header panel sudah include video background
                    const SizedBox(height: 24),
                    _buildInputPanel(),
                    _buildSendButton(),
                    _buildResponseMessage(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
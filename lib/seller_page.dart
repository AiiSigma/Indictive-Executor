import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class SellerPage extends StatefulWidget {
  final String keyToken;

  const SellerPage({super.key, required this.keyToken});

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  final _newUser = TextEditingController();
  final _newPass = TextEditingController();
  final _days = TextEditingController();
  final _editUser = TextEditingController();
  final _editDays = TextEditingController();
  bool loading = false;

// Tema hitam – abu (tanpa ubah nama const)
final Color bloodRed  = const Color(0xFF5C1B1B); // maron utama (agak gelap)
final Color darkRed   = const Color(0xFF3F1212); // maron lebih gelap (depth)
final Color lightRed  = const Color(0xFFA94A4A); // maron terang (highlight)
final Color deepBlack = const Color(0xFF0D0D0D); // hitam netral
final Color cardDark  = const Color(0xFF2A1010); // card maron gelap

  Future<void> _create() async {
    final u = _newUser.text.trim(), p = _newPass.text.trim(), d = _days.text.trim();
    if (u.isEmpty || p.isEmpty || d.isEmpty) return _alert("❗ Semua field wajib diisi");
    setState(() => loading = true);
    final res = await http.get(Uri.parse(
        "http://127.0.0.1:3000/createAccount?key=${widget.keyToken}&newUser=$u&pass=$p&day=$d"));
    final data = jsonDecode(res.body);
    if (data['created'] == true) {
      _alert("✅ Akun berhasil dibuat!");
      _newUser.clear(); _newPass.clear(); _days.clear();
    } else {
      _alert("❌ ${data['message'] ?? 'Gagal membuat akun.'}");
    }
    setState(() => loading = false);
  }

  Future<void> _edit() async {
    final u = _editUser.text.trim(), d = _editDays.text.trim();
    if (u.isEmpty || d.isEmpty) return _alert("❗ Username dan durasi wajib diisi");
    setState(() => loading = true);
    final res = await http.get(Uri.parse(
        "http://127.0.0.1:3000/editUser?key=${widget.keyToken}&username=$u&addDays=$d"));
    final data = jsonDecode(res.body);
    if (data['edited'] == true) {
      _alert("✅ Durasi berhasil diperbarui.");
      _editUser.clear(); _editDays.clear();
    } else {
      _alert("❌ ${data['message'] ?? 'Gagal mengubah durasi.'}");
    }
    setState(() => loading = false);
  }

  void _alert(String msg) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: bloodRed.withOpacity(0.3), width: 1.5),
          ),
          content: Text(
            msg,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: bloodRed)),
            )
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
            cardDark,
            cardDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bloodRed.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bloodRed.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            cardDark,
            cardDark.withOpacity(0.8),
          ],
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        cursorColor: bloodRed,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: bloodRed),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: bloodRed.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: bloodRed, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: bloodRed.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: bloodRed, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
      backgroundColor: deepBlack,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    bloodRed.withOpacity(0.1),
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
                  colors: [
                    darkRed.withOpacity(0.08),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store, color: bloodRed, size: 32),
                          const SizedBox(width: 12),
                          const Text(
                            "RESELLER PANEL",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Buat Akun Baru", Icons.person_add),

                          _buildGlassInputField(
                            controller: _newUser,
                            label: "Username",
                            icon: Icons.person_outline,
                          ),

                          _buildGlassInputField(
                            controller: _newPass,
                            label: "Password",
                            icon: Icons.lock_outline,
                            obscureText: true,
                          ),

                          _buildGlassInputField(
                            controller: _days,
                            label: "Durasi (hari)",
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                          ),

                          const SizedBox(height: 8),

                          _buildActionButton(
                            text: "BUAT AKUN",
                            icon: Icons.person_add,
                            onPressed: _create,
                            color: bloodRed,
                            isLoading: loading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Ubah Durasi", Icons.edit_calendar),

                          _buildGlassInputField(
                            controller: _editUser,
                            label: "Username",
                            icon: Icons.person_outline,
                          ),

                          _buildGlassInputField(
                            controller: _editDays,
                            label: "Tambah Durasi (hari)",
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                          ),

                          const SizedBox(height: 8),

                          _buildActionButton(
                            text: "UBAH DURASI",
                            icon: Icons.edit,
                            onPressed: _edit,
                            color: darkRed,
                            isLoading: loading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: bloodRed, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Gunakan panel ini untuk mengelola akun reseller Anda",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
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
        ],
      ),
    );
  }
}
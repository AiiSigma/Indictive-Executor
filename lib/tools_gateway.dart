import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'manage_server.dart';
import 'wifi_internal.dart';
import 'wifi_external.dart';
import 'ddos_panel.dart';
import 'nik_check.dart';
import 'tiktok_page.dart';
import 'instagram_page.dart';
import 'qr_gen.dart';
import 'domain_page.dart';
import 'spam_ngl.dart';

class ToolsPage extends StatefulWidget {
  final String sessionKey;
  final String userRole;
  final List<Map<String, dynamic>> listDoos;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.listDoos,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _cardController;
  late Animation<double> _bgAnimation;
  late Animation<double> _cardAnimation;

// ===== SOFT GREY (LOW OPACITY) =====
final Color primaryDark  = const Color(0xFFECECEC);              // background abu terang
final Color primaryBlue  = Colors.grey.withOpacity(0.50);       // abu solid-ish (header / card)
final Color accentBlue   = Colors.black.withOpacity(0.18);      // border hitam tipis
final Color lightBlue    = Colors.grey.withOpacity(0.50);       // divider / highlight
final Color primaryWhite = const Color(0xFF121212);              // teks utama (hitam lembut)
final Color accentGrey   = const Color(0xFF6A6A6A);              // teks sekunder
final Color cardDark     = Colors.grey.withOpacity(0.50);       // card abu (sedikit transparan)

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _bgAnimation = Tween<double>(begin: 0, end: 1).animate(_bgController);
    _cardAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutCubic,
      ),
    );

    _cardController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: Stack(
        children: [
          // Background dengan animasi partikel
          _buildAnimatedBackground(),

          // Konten utama
          SafeArea(
            child: Column(
              children: [
                // Header dengan desain baru
                _buildNewHeader(),

                // Kategori tools dengan desain baru
                Expanded(
                  child: _buildToolCategories(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF202020),
                    const Color(0xFF1A1A1A),
                  ],
                ),
              ),
            ),

            // Partikel animasi
            ...List.generate(20, (index) {
              final top = (_bgAnimation.value + index * 0.05) % 1.0;
              final left = (index * 0.1) % 1.0;
              final size = 10.0 + (index % 5) * 5.0;
              final opacity = 0.1 + (index % 3) * 0.1;

              return Positioned(
                top: top * MediaQuery.of(context).size.height,
                left: left * MediaQuery.of(context).size.width,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(opacity),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: lightBlue.withOpacity(opacity * 0.5),
                        blurRadius: size,
                        spreadRadius: size / 2,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Efek cahaya
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedBuilder(
                animation: _bgAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _bgAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentBlue.withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Logo dan judul
          Row(
            children: [
              // Logo dengan animasi
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryBlue, accentBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: accentBlue.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 16),

              // Judul
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Misc Tools",
                      style: TextStyle(
                        color: primaryWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      "Advanced Security Suite",
                      style: TextStyle(
                        color: lightBlue,
                        fontSize: 14,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ),

              // Status user
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentBlue.withOpacity(0.5)),
                ),
                child: Text(
                  widget.userRole.toUpperCase(),
                  style: TextStyle(
                    color: lightBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
            ],
          ),

          // Search bar
        ],
      ),
    );
  }

  Widget _buildToolCategories() {
    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _cardAnimation.value) * 50),
          child: Opacity(
            opacity: _cardAnimation.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Bar kategori dengan scroll horizontal
                  // Grid tools dengan desain baru
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        return _buildNewToolCard(index);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentBlue : accentBlue.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryWhite : lightBlue,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildNewToolCard(int index) {
    final List<Map<String, dynamic>> tools = [
      {
        "icon": Icons.wifi,
        "title": "Network",
        "subtitle": "WiFi & Spam",
        "color": accentBlue,
        "onTap": () => _showNetworkTools(context),
      },
      {
        "icon": Icons.search,
        "title": "OSINT",
        "subtitle": "Investigation",
        "color": accentBlue,
        "onTap": () => _showOSINTTools(context),
      },
      {
        "icon": Icons.download,
        "title": "Downloader",
        "subtitle": "Social Media",
        "color": accentBlue,
        "onTap": () => _showDownloaderTools(context),
      },
      {
        "icon": Icons.build,
        "title": "Utilities",
        "subtitle": "Extra Tools",
        "color": accentBlue,
        "onTap": () => _showUtilityTools(context),
      },
    ];

    final tool = tools[index];

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: tool["onTap"],
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tool["color"].withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tool["color"].withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon dengan background gradien
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryBlue, tool["color"]],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: tool["color"].withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            tool["icon"],
                            color: primaryWhite,
                            size: 28,
                          ),
                        ),

                        const Spacer(),

                        // Judul dan subtitle
                        Text(
                          tool["title"],
                          style: TextStyle(
                            color: primaryWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          tool["subtitle"],
                          style: TextStyle(
                            color: lightBlue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDDoSTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNewModalSheet(
        context,
        "DDoS Tools",
        Icons.flash_on,
        [
          _buildModalOption(
            icon: Icons.flash_on,
            label: "Attack Panel",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttackPanel(
                    sessionKey: widget.sessionKey,
                    listDoos: widget.listDoos,
                  ),
                ),
              );
            },
          ),
          _buildModalOption(
            icon: Icons.dns,
            label: "Manage Server",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageServerPage(keyToken: widget.sessionKey),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNetworkTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNewModalSheet(
        context,
        "Network Tools",
        Icons.wifi,
        [
          _buildModalOption(
            icon: Icons.newspaper_outlined,
            label: "Spam NGL",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NglPage()),
              );
            },
          ),
          _buildModalOption(
            icon: Icons.wifi_off,
            label: "WiFi Killer (Internal)",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WifiKillerPage()),
              );
            },
          ),
          if (widget.userRole == "vip" || widget.userRole == "owner")
            _buildModalOption(
              icon: Icons.router,
              label: "WiFi Killer (External)",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WifiInternalPage(sessionKey: widget.sessionKey),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showOSINTTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNewModalSheet(
        context,
        "OSINT Tools",
        Icons.search,
        [
          _buildModalOption(
            icon: Icons.badge,
            label: "NIK Detail",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NikCheckerPage()),
              );
            },
          ),
          _buildModalOption(
            icon: Icons.person_search,
            label: "Phone Lookup",
            onTap: () => _showComingSoon(context),
          ),
          _buildModalOption(
            icon: Icons.email,
            label: "Email OSINT",
            onTap: () => _showComingSoon(context),
          ),
        ],
      ),
    );
  }

  void _showDownloaderTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNewModalSheet(
        context,
        "Media Downloader",
        Icons.download,
        [
          _buildModalOption(
            icon: Icons.video_library,
            label: "TikTok Downloader",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TiktokDownloaderPage()),
              );
            },
          ),
          _buildModalOption(
            icon: Icons.camera_alt,
            label: "Instagram Downloader",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InstagramDownloaderPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showUtilityTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNewModalSheet(
        context,
        "Utility Tools",
        Icons.build,
        [
          _buildModalOption(
            icon: Icons.qr_code,
            label: "QR Generator",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrGeneratorPage()),
              );
            },
          ),
          _buildModalOption(
            icon: Icons.security,
            label: "IP Scanner",
            onTap: () => _showComingSoon(context),
          ),
          _buildModalOption(
            icon: Icons.network_check,
            label: "Port Scanner",
            onTap: () => _showComingSoon(context),
          ),
        ],
      ),
    );
  }

  void _showQuickAccess(BuildContext context) {
    _showComingSoon(context);
  }

  Widget _buildNewModalSheet(
      BuildContext context,
      String title,
      IconData icon,
      List<Widget> options,
      ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border.all(color: accentBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header modal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, accentBlue],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primaryWhite),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 20,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Opsi-opsi
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: options,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentBlue.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryBlue, accentBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryWhite),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: primaryWhite,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accentBlue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_forward_ios, color: lightBlue, size: 14),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.hourglass_top, color: primaryWhite),
            const SizedBox(width: 8),
            Text(
              'Feature Coming Soon!',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: primaryWhite,
              ),
            ),
          ],
        ),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
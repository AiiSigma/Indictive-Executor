import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'bug_page.dart';
import 'login_page.dart';
import 'chat_private.dart';
import 'chat_home_page.dart';
import 'tools_gateway.dart';
import 'wifi_internal.dart';
import 'chat_public.dart';
import 'chatbot_page.dart';
import 'dashboard_chat.dart';
import 'change_password_page.dart';
import 'nik_check.dart';
import 'admin_page.dart';
import 'seller_page.dart';
import 'bug_sender.dart';
import 'anime_home.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String sessionKey;
  final String expiredDate;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.sessionKey,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const bannerUrl = 'https://pomf2.lain.la/f/o6rnuqvv.jpg';

  late WebSocketChannel channel;
  String androidId = "unknown";

  int _selectedTabIndex = 0;
  late Widget _selectedPage;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ===== THEME (RED EDITION) =====
  final Color bg = const Color(0xFF0B0B0B);
  final Color yellow = const Color(0xFFDC2626);
  final Color purple = const Color(0xFF991B1B);

  @override
  void initState() {
    super.initState();
    _initAndroidIdAndConnect();
    _selectedPage = _buildHomePage();
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse('http://127.0.0.1:3000'),
    );

    channel.sink.add(jsonEncode({
      "type": "validate",
      "key": widget.sessionKey,
      "androidId": androidId,
    }));
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    super.dispose();
  }

  // ================= SIDEBAR =================
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: bg,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg, purple.withOpacity(0.5)],
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    "RavenXTeam",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: yellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: yellow.withOpacity(0.4)),
                    ),
                    child: Text(
                      widget.role.toUpperCase(),
                      style: TextStyle(
                        color: yellow,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // QUICK ACCESS SECTION
                _drawerSectionHeader("Quick Access"),
                _drawerItem(Icons.home, "Home", () {
                  Navigator.pop(context);
                  _onTabTapped(0);
                }),
                _drawerItem(Icons.call_missed, "WhatsApp", () {
                  Navigator.pop(context);
                  _onTabTapped(1);
                }),
                _drawerItem(Icons.flash_on, "Wi-Fi Panel", () {
                  Navigator.pop(context);
                  _onTabTapped(2);
                }),
                _drawerItem(Icons.smart_toy_outlined, "ChatBot", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AiChatPage(),
                  ));
                }),

                const Divider(color: Colors.white24, height: 20),

                // TOOLS SECTION
                _drawerSectionHeader("Tools & Features"),
                _drawerItem(Icons.build_circle, "Misc Tools", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ToolsPage(
                      sessionKey: widget.sessionKey,
                      userRole: widget.role,
                      listDoos: widget.listDoos,
                    ),
                  ));
                }),
                _drawerItem(Icons.phone_in_talk, "Bug Sender", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BugSenderPage(
                      sessionKey: widget.sessionKey,
                      username: widget.username,
                      role: widget.role,
                    ),
                  ));
                }),
                _drawerItem(Icons.tv, "Anime", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const HomeAnimePage(),
                  ));
                }),
                _drawerItem(Icons.person_search, "NIK Check", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const NikCheckerPage(),
                  ));
                }),

                const Divider(color: Colors.white24, height: 20),

                // ACCOUNT SECTION
                _drawerSectionHeader("Account"),
                if (widget.role == "owner")
                  _drawerItem(Icons.admin_panel_settings, "Admin Page", () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AdminPage(sessionKey: widget.sessionKey),
                    ));
                  }),

                if (widget.role == "reseller")
                  _drawerItem(Icons.add_shopping_cart, "Seller Page", () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SellerPage(keyToken: widget.sessionKey),
                    ));
                  }),

                _drawerItem(Icons.lock, "Change Password", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChangePasswordPage(
                      username: widget.username,
                      sessionKey: widget.sessionKey,
                    ),
                  ));
                }),

                // LOGOUT
                _drawerItem(Icons.logout, "Logout", () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(context, "/login", (r) => false);
                }),

                const Divider(color: Colors.white24, height: 32),

                // THANKS TO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Thanks To",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text("- PermenMD {Inspired}", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text("- KaiiOfficial {Creators Base}", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text("- Zsnz {Best Friends}", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text("- Zyrex {Hitam Nigeria}", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: yellow.withOpacity(0.7),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: yellow.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: yellow, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      dense: true,
      onTap: onTap,
    );
  }

  // ================= NAVBAR LOGIC =================
  void _onTabTapped(int index) {
    setState(() {
      _selectedTabIndex = index;

      if (index == 0) {
        _selectedPage = _buildHomePage();
      } else if (index == 1) {
        _selectedPage = BugPage(
          username: widget.username,
          password: widget.password,
          role: widget.role,
          expiredDate: widget.expiredDate,
          sessionKey: widget.sessionKey,
          listBug: widget.listBug,
          listDoos: widget.listDoos,
        );
      } else if (index == 2) {
        _selectedPage = WifiKillerPage();
      } else if (index == 3) {
        _selectedPage = GoToChatBot(username: widget.username);
      } else if (index == 4) {
        _selectedPage = ToolsPage(
          sessionKey: widget.sessionKey,
          userRole: widget.role,
          listDoos: widget.listDoos,
        );
      }
    });
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      backgroundColor: bg,

      // HEADER DENGAN SHADOW
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E0E),
            boxShadow: [
              BoxShadow(
                color: yellow.withOpacity(0.35),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: const Text(
              "RavenXTeam",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: yellow.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: yellow.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: yellow, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      widget.username,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),

      body: _selectedPage,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          border: Border(
            top: BorderSide(
              color: yellow.withOpacity(0.15),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedTabIndex,
          onTap: _onTabTapped,
          selectedItemColor: yellow,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.call), label: 'WhatsApp'),
            BottomNavigationBarItem(icon: Icon(Icons.flash_on), label: 'Wi-Fi'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.build_circle), label: 'Tools'),
          ],
        ),
      ),
    );
  }

  // ================= HOME PAGE (REDESIGNED) =================
  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BANNER
          _banner(),
          const SizedBox(height: 22),

          // SECTION: MAIN FEATURES
          _sectionTitle("Main Features"),
          const SizedBox(height: 14),

          // ROW 1: Quick Actions (Circle Buttons)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _circleMenu(Icons.call_missed, "WhatsApp", Colors.redAccent, () {
                _onTabTapped(1);
              }),
              _circleMenu(Icons.flash_on, "Wi-Fi", Colors.orangeAccent, () {
                _onTabTapped(2);
              }),
              _circleMenu(Icons.chat, "Chat", Colors.blueAccent, () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatHomePage(myName: widget.username),
                ));
              }),
              _circleMenu(Icons.smart_toy_outlined, "ChatBot", Colors.tealAccent, () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AiChatPage(),
                ));
              }),
            ],
          ),

          const SizedBox(height: 28),

          // SECTION: TOOLS & FEATURES (Card Style)
          _sectionTitle("Tools & Features"),
          const SizedBox(height: 14),

          // CARD: Misc Tools
          _featureCard(
            icon: Icons.build_circle,
            iconColor: Colors.deepPurpleAccent,
            title: "Misc Tools",
            subtitle: "Network, OSINT, Downloader & more",
            gradient: [Colors.deepPurple.withOpacity(0.15), Colors.purple.withOpacity(0.05)],
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ToolsPage(
                  sessionKey: widget.sessionKey,
                  userRole: widget.role,
                  listDoos: widget.listDoos,
                ),
              ));
            },
          ),

          const SizedBox(height: 12),

          // CARD: Bug Sender
          _featureCard(
            icon: Icons.phone_in_talk,
            iconColor: Colors.greenAccent,
            title: "Bug Sender",
            subtitle: "Manage WhatsApp Sender & Pairing",
            gradient: [Colors.green.withOpacity(0.15), Colors.teal.withOpacity(0.05)],
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => BugSenderPage(
                  sessionKey: widget.sessionKey,
                  username: widget.username,
                  role: widget.role,
                ),
              ));
            },
          ),

          const SizedBox(height: 12),

          // CARD: Anime
          _featureCard(
            icon: Icons.tv,
            iconColor: Colors.blueAccent,
            title: "Anime",
            subtitle: "Watch your favorite anime",
            gradient: [Colors.blue.withOpacity(0.15), Colors.indigo.withOpacity(0.05)],
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const HomeAnimePage(),
              ));
            },
          ),

          const SizedBox(height: 24),

          // TELEGRAM BANNER
          GestureDetector(
            onTap: () async {
              await launchUrl(
                Uri.parse("https://t.me/RavenChannels"),
                mode: LaunchMode.externalApplication,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [yellow, purple]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: yellow.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.group_add, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Telegram Channel: Join To Get More Info!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SERVER STATS
          _serverStats(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ================= UI COMPONENTS =================

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: yellow.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iconColor.withOpacity(0.3)),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Image.network(
            bannerUrl,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.black.withOpacity(0.2),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          const Positioned(
            left: 18,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "RavenXTeam",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Inspired By @permen_md",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // Decorative glow top-right
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: yellow.withOpacity(0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleMenu(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(
                color: color.withOpacity(0.5),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ================= SERVER STATS =================
  Widget _serverStats() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  purple.withOpacity(0.90),
                  yellow.withOpacity(0.90),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: const Row(
              children: [
                Text("📊", style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text(
                  "Server Stats",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // BODY
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  purple,
                  bg.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
            ),
            child: Column(
              children: [
                _statsRowLine(
                  emoji: "👥",
                  label: "Online Users",
                  value: "0",
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: Colors.white24),
                const SizedBox(height: 12),
                _statsRowLine(
                  emoji: "🚀",
                  label: "Active Sender",
                  value: "0",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRowLine({
    required String emoji,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 28,
          color: Colors.white24,
        ),
        SizedBox(
          width: 40,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: yellow,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

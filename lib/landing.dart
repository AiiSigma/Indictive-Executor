import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {

  late AnimationController _masterCtrl;

  late Animation<double>  _topFade;
  late Animation<Offset>  _topSlide;

  late Animation<double>  _profileFade;
  late Animation<Offset>  _profileSlide;

  late Animation<double>  _bottomFade;
  late Animation<Offset>  _bottomSlide;

  late Animation<double>  _btnFade;
  late Animation<Offset>  _btnSlide;
  late Animation<double>  _btnScale;

  late Animation<double>  _footerFade;

  late AnimationController _pulseCtrl;
  late Animation<double>  _pulseAnim;

  late AnimationController _shimmerCtrl;

  late VideoPlayerController _bgVideo;
  bool _videoReady = false;

  static const Color _accentRed  = Color(0xFFFF1744);
  static const Color _bgDark     = Color(0xFF07090F);
  static const Color _cardDark   = Color(0xFF0D1424);
  static const Color _borderDark = Color(0xFF3A1520);
  static const Color _deepRed    = Color(0xFF8B0000);
  static const Color _softRed    = Color(0xFFE53935);
  static const Color _glowRed    = Color(0xFFFF5252);

  static const String _gallery1 = 'https://files.catbox.moe/6i5kip.jpg';
  static const String _gallery2 = 'https://files.catbox.moe/vxw3rv.jpg';
  static const String _gallery3 = 'https://files.catbox.moe/joaztm.jpg';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVideo();
  }

  void _initAnimations() {
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _topFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _topSlide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    ));

    _profileFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.10, 0.42, curve: Curves.easeOut),
      ),
    );
    _profileSlide = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.10, 0.42, curve: Curves.easeOutCubic),
    ));

    _bottomFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.22, 0.58, curve: Curves.easeOut),
      ),
    );
    _bottomSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.22, 0.58, curve: Curves.easeOutCubic),
    ));

    _btnFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.40, 0.78, curve: Curves.easeOut),
      ),
    );
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.40, 0.78, curve: Curves.easeOutCubic),
    ));
    _btnScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.60, 1.0, curve: Curves.elasticOut),
      ),
    );

    _footerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.50, 0.85, curve: Curves.easeOut),
      ),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _masterCtrl.forward();
  }

  void _initVideo() {
    _bgVideo = VideoPlayerController.asset('assets/videos/landing.mp4')
      ..initialize().then((_) {
        _bgVideo.setLooping(true);
        _bgVideo.setVolume(0.0);
        _bgVideo.play();
        setState(() { _videoReady = true; });
      });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _bgVideo.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  Future<String?> _fetchRegisterCode() async {
    try {
      final res = await http.get(Uri.parse("http://127.0.0.1:3000/getCode"));
      if (res.statusCode == 200) {
        final jsonData = jsonDecode(res.body);
        return jsonData["code"]?.toString();
      }
    } catch (e) {
      debugPrint("Error fetching code: $e");
    }
    return null;
  }

  Future<void> _signInWith(String type) async {
    final code = await _fetchRegisterCode();
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get registration code.")),
      );
      return;
    }

    final message = Uri.encodeComponent("""
{ IndictiveCore }
Executor Team
Type: Register
Code: $code
Role: Member
""");

    if (type == "whatsapp") {
      final whatsappUrl = "https://wa.me/6283820463478";
      await _openUrl(whatsappUrl);
    } else if (type == "telegram") {
      final telegramUrl = "https://t.me/AiiSigma";
      await _openUrl(telegramUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _videoReady
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _bgVideo.value.size.width,
                      height: _bgVideo.value.size.height,
                      child: VideoPlayer(_bgVideo),
                    ),
                  ),
                )
              : Container(color: _bgDark),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.60),
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.50),
                  Colors.black.withOpacity(0.92),
                ],
                stops: const [0.0, 0.28, 0.65, 1.0],
              ),
            ),
          ),

          ..._buildFloatingParticles(),

          SafeArea(
            child: Column(
              children: [
                FadeTransition(
                  opacity: _topFade,
                  child: SlideTransition(
                    position: _topSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBrandBadge(),
                          const Spacer(),
                          _buildGalleryPanel(),
                        ],
                      ),
                    ),
                  ),
                ),

                FadeTransition(
                  opacity: _profileFade,
                  child: SlideTransition(
                    position: _profileSlide,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(left: 16, right: 16, top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildSystemProfile(),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                FadeTransition(
                  opacity: _bottomFade,
                  child: SlideTransition(
                    position: _bottomSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WELCOME TO',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 5,
                              fontFamily: 'ShareTechMono',
                            ),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (context, child) {
                                  return Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _glowRed.withOpacity(
                                            _pulseAnim.value * 0.6),
                                        width: 2.5,
                                      ),
                                      color: _cardDark,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _glowRed.withOpacity(
                                              _pulseAnim.value * 0.35),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/logo.jpg',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.security_rounded,
                                          color: _softRed,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 14),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedBuilder(
                                    animation: _shimmerCtrl,
                                    builder: (context, child) {
                                      return ShaderMask(
                                        shaderCallback: (bounds) {
                                          final shimmerValue =
                                              _shimmerCtrl.value;
                                          return LinearGradient(
                                            colors: const [
                                              Colors.white,
                                              Color(0xFFFF5252),
                                              Color(0xFFFF1744),
                                              Colors.white,
                                              Color(0xFFE53935),
                                              Colors.white,
                                            ],
                                            stops: [
                                              (shimmerValue - 0.1)
                                                  .clamp(0.0, 1.0),
                                              (shimmerValue)
                                                  .clamp(0.0, 1.0),
                                              (shimmerValue + 0.1)
                                                  .clamp(0.0, 1.0),
                                              (shimmerValue + 0.3)
                                                  .clamp(0.0, 1.0),
                                              (shimmerValue + 0.4)
                                                  .clamp(0.0, 1.0),
                                              (shimmerValue + 0.5)
                                                  .clamp(0.0, 1.0),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds);
                                        },
                                        child: const Text(
                                          'RAVENGETSUZO',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Orbitron',
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'IndictiveCore  \u00B7  Premium Access',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.50),
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                      fontFamily: 'ShareTechMono',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                FadeTransition(
                  opacity: _btnFade,
                  child: SlideTransition(
                    position: _btnSlide,
                    child: ScaleTransition(
                      scale: _btnScale,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Column(
                          children: [
                            _buildActionButton(
                              label: 'SIGN-IN USING USERNAME',
                              icon: Icons.person_outline_rounded,
                              bgColor: _deepRed,
                              glowColor: _accentRed,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginPage()),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              label: 'SIGN-IN USING TELEGRAM',
                              icon: Icons.send_rounded,
                              bgColor: const Color(0xFF1565C0),
                              glowColor: const Color(0xFF42A5F5),
                              onTap: () => _signInWith("telegram"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                FadeTransition(
                  opacity: _footerFade,
                  child: _buildFooter(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingParticles() {
    return List.generate(15, (i) {
      final random = math.Random(i + 42);
      final topFraction = random.nextDouble();
      final leftFraction = random.nextDouble();
      final size = random.nextDouble() * 3 + 1;

      return Positioned(
        top: topFraction * 800,
        left: leftFraction * 400,
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, child) {
            final phase = (i * 0.3 + _shimmerCtrl.value) % 1.0;
            final opacity = math.sin(phase * math.pi) * 0.25;
            final yOffset = math.sin(phase * math.pi * 2) * 15;
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Opacity(
                opacity: opacity.clamp(0.0, 0.25),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: _glowRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _glowRed.withOpacity(0.3),
                        blurRadius: size * 3,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildBrandBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_deepRed, _accentRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _accentRed.withOpacity(0.5),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Text(
        'RAVENGETSUZO',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildGalleryPanel() {
    final List<String> imgs = [_gallery1, _gallery2, _gallery3];

    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDark.withOpacity(0.7), width: 1),
        boxShadow: [
          BoxShadow(
            color: _accentRed.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_deepRed, _accentRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'GALLERY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: GestureDetector(
                onTap: () => _openUrl(imgs[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    imgs[i],
                    width: 64,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _cardDark,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: _borderDark.withOpacity(0.5), width: 1),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_outlined,
                            color: Colors.white24, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSystemProfile() {
    return Container(
      width: 215,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDark.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: _accentRed.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: Colors.white.withOpacity(0.12), width: 1),
            ),
            child: const Text(
              'SYSTEM PROFILE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 8.5,
                letterSpacing: 2,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ),
          const SizedBox(height: 10),

          const Text(
            'RavenGetSuzo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'ShareTechMono',
            ),
          ),
          const SizedBox(height: 8),

          _profileRow('Theme', 'RavenGetSuzo'),
          _profileRow('Node', 'Premium'),
          _profileRow('Status', 'Online'),
          _profileRow('Version', 'v2.0.0'),
        ],
      ),
    );
  }

  Widget _profileRow(String key, String val) {
    final isStatus = key == 'Status';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          if (isStatus)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'ShareTechMono',
                fontSize: 11,
                height: 1.6,
              ),
              children: [
                TextSpan(
                    text: '$key: ',
                    style: const TextStyle(color: Colors.white54)),
                TextSpan(
                    text: val,
                    style: TextStyle(
                      color: isStatus
                          ? Colors.greenAccent
                          : Colors.white,
                      fontWeight: isStatus ? FontWeight.w600 : FontWeight.normal,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, glowColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.45),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Contact Us',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontFamily: 'ShareTechMono',
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openUrl("https://t.me/AiiSigma"),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3), width: 1),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _openUrl("https://tiktok.com/@aiistecu"),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '\u00A9 2026 IndictiveCore',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontFamily: 'ShareTechMono',
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
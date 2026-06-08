import 'dart:async'; // Impor library untuk Timer
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';

class SplashScreen extends StatefulWidget {
  // ... (properti tetap sama)
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
    required this.listBug,
    required this.listDoos,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _fadeController;
  bool _fadeOutStarted = false;
  double _videoProgress = 0.0;
  bool _isNavigating = false;
  Timer? _videoTimeoutTimer; // Timer untuk handle video yang tidak berhasil dimuat

  @override
  void initState() {
    super.initState();

    // 1. Inisialisasi AnimationController di sini agar selalu tersedia
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // 2. Mulai timer untuk timeout
    _videoTimeoutTimer = Timer(const Duration(seconds: 10), () {
      // Jika setelah 10 detik video belum siap, otomatis skip
      if (!_isNavigating) {
        _skipIntro();
      }
    });

    // 3. Inisialisasi dan coba muat video
    _videoController = VideoPlayerController.asset("assets/videos/splash.mp4")
      ..initialize().then((_) {
        // Jika berhasil diinisialisasi, batalkan timer
        _videoTimeoutTimer?.cancel();
        setState(() {});
        _videoController.setLooping(false);
        _videoController.play();

        _videoController.addListener(() {
          if (_videoController.value.isInitialized) {
            final position = _videoController.value.position;
            final duration = _videoController.value.duration;

            if (duration != null) {
              setState(() {
                _videoProgress = position.inMilliseconds / duration.inMilliseconds;
              });
            }

            if (duration != null &&
                position >= duration - const Duration(seconds: 1) &&
                !_fadeOutStarted) {
              _fadeOutStarted = true;
              _fadeController.forward().then((_) {
                _navigateToDashboard();
              });
            }

            if (position >= duration && !_isNavigating) {
              _navigateToDashboard();
            }
          }
        });
      }).catchError((error) {
        // 4. Tangani error jika video gagal dimuat
        print("Error loading video: $error");
        _videoTimeoutTimer?.cancel(); // Batalkan timer juga saat error
        // Langsung lanjutkan ke dashboard setelah delay singkat
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isNavigating) {
            _skipIntro();
          }
        });
      });
  }

  void _navigateToDashboard() {
    _isNavigating = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          username: widget.username,
          password: widget.password,
          role: widget.role,
          expiredDate: widget.expiredDate,
          sessionKey: widget.sessionKey,
          listBug: widget.listBug,
          listDoos: widget.listDoos,
        ),
      ),
    );
  }

  void _skipIntro() {
    if (_isNavigating) return;

    _videoTimeoutTimer?.cancel(); // Batalkan timer saat skip manual
    _isNavigating = true;
    _fadeOutStarted = true;

    // Hentikan video jika sedang diputar
    if (_videoController.value.isInitialized) {
      _videoController.pause();
    }

    _fadeController.forward().then((_) {
      _navigateToDashboard();
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _fadeController.dispose();
    _videoTimeoutTimer?.cancel(); // Penting: batalkan timer untuk mencegah memory leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 5. Bungkus seluruh body dengan GestureDetector agar bisa di-tap di mana saja
      body: GestureDetector(
        onTap: _skipIntro,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video atau indikator loading
            if (_videoController.value.isInitialized)
              Center(
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: _videoController.value.aspectRatio,
                        child: VideoPlayer(_videoController),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                ),
              ),

            // Teks, Loading Bar, dan Tombol Skip
            Positioned(
              bottom: 80,
              child: Column(
                children: [
                  Text(
                    "RavenGetSuzo",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: Colors.purpleAccent.withOpacity(0.9),
                          blurRadius: 10,
                          offset: const Offset(2, 2),
                        ),
                        Shadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 15,
                          offset: const Offset(-2, -2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Loading Bar
                  Container(
                    width: 200,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _videoProgress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purpleAccent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tombol Skip
                  ElevatedButton(
                    onPressed: _skipIntro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      "Lewati Intro",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Fade out effect
            if (_fadeOutStarted)
              FadeTransition(
                opacity: _fadeController.drive(Tween(begin: 1.0, end: 0.0)),
                child: Container(color: Colors.black),
              ),
          ],
        ),
      ),
    );
  }
}
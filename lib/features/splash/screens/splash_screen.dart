import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../gestures/data/custom_gesture_repository.dart';
import '../../gestures/services/gesture_platform_service.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../onboarding/services/onboarding_storage_service.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../animations/splash_animations.dart';
import '../widgets/splash_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final SplashAnimations _animations;
  final OnboardingStorageService _storageService = OnboardingStorageService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _animations = SplashAnimations(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });

    _controller.forward();
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    // Synchronize custom gestures from SQLite to native SharedPreferences on startup
    try {
      final customRepo = SqliteCustomGestureRepository();
      final customs = await customRepo.getAllGestures();
      final gestureService = GesturePlatformService();
      await gestureService.syncCustomGestures(customs);
      debugPrint('[ReelSenseGestureSync] Startup sync completed: ${customs.length} custom gestures synced.');
    } catch (e) {
      debugPrint('[ReelSenseGestureSync] Startup sync warning: $e');
    }

    final hasCompleted = await _storageService.hasCompletedOnboarding();

    if (!mounted) return;

    final targetScreen =
        hasCompleted ? const DashboardScreen() : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient gradient orbs
          AnimatedBuilder(
            animation: _animations.ambientOpacity,
            builder: (context, child) {
              return Opacity(
                opacity: _animations.ambientOpacity.value,
                child: Stack(
                  children: [
                    // Purple Ambient Orb (Top-Right)
                    Positioned(
                      top: screenHeight * 0.15,
                      right: -60,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primaryPurple.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Cyan Ambient Orb (Bottom-Left)
                    Positioned(
                      bottom: screenHeight * 0.20,
                      left: -60,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentCyan.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Central Logo, Animated Name, and Tagline
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // ReelSense App Logo (Real Logo from splashscreenimg.png)
                Center(
                  child: SplashLogo(
                    fadeAnimation: _animations.logoFade,
                    scaleAnimation: _animations.logoScale,
                    size: 130,
                  ),
                ),
                const SizedBox(height: 28),

                // Animated Wordmark
                FadeTransition(
                  opacity: _animations.wordmarkFade,
                  child: SlideTransition(
                    position: _animations.wordmarkSlide,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return AppColors.primaryGradient.createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        );
                      },
                      child: const Text(
                        'ReelSense',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Tagline Reveal
                FadeTransition(
                  opacity: _animations.taglineFade,
                  child: SlideTransition(
                    position: _animations.taglineSlide,
                    child: const Text(
                      'Scroll Without Touch.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 4),

                // Developer by Brijesh Verma with Heart
                FadeTransition(
                  opacity: _animations.footerFade,
                  child: SlideTransition(
                    position: _animations.footerSlide,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Developed with ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFF3366),
                            size: 16,
                          ),
                          const Text(
                            ' by ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                colors: [
                                  Colors.white,
                                  AppColors.accentCyan,
                                ],
                              ).createShader(
                                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                              );
                            },
                            child: const Text(
                              'Brijesh Verma',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

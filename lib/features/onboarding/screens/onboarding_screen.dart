import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../models/onboarding_page_model.dart';
import '../services/onboarding_storage_service.dart';
import '../widgets/onboarding_navigation.dart';
import '../widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  final OnboardingStorageService _storageService = OnboardingStorageService();
  int _currentPage = 0;

  static const List<OnboardingPageModel> _pages = [
    // Page 1: Meet ReelSense
    OnboardingPageModel(
      index: 0,
      title: 'Your Reels, Your Control.',
      description:
          'Control your favourite short-video experiences without touching your phone.',
      featurePoints: [
        OnboardingFeaturePoint(
          icon: Icons.swipe_vertical_rounded,
          title: 'Hands-free scrolling',
          subtitle: 'Navigate reels effortlessly while eating, working or relaxing',
        ),
        OnboardingFeaturePoint(
          icon: Icons.record_voice_over_rounded,
          title: 'Voice commands',
          subtitle: 'Speak simple triggers to scroll, like or pause',
        ),
        OnboardingFeaturePoint(
          icon: Icons.pan_tool_rounded,
          title: 'Hand gesture controls',
          subtitle: 'Wave or hold your hand to trigger seamless playback actions',
        ),
      ],
    ),

    // Page 2: How It Works
    OnboardingPageModel(
      index: 1,
      title: 'Speak It. Gesture It. Control It.',
      description:
          'Create your own commands and control scrolling your way.',
      featurePoints: [
        OnboardingFeaturePoint(
          icon: Icons.tune_rounded,
          title: 'Add custom voice commands',
          subtitle: 'Personalize keyword triggers to fit your speech and rhythm',
        ),
        OnboardingFeaturePoint(
          icon: Icons.gesture_rounded,
          title: 'Assign actions to recognized gestures',
          subtitle: 'Bind palm, swipe, or point movements to navigation events',
        ),
        OnboardingFeaturePoint(
          icon: Icons.play_circle_outline_rounded,
          title: 'Start a Reel Session before controlling Instagram',
          subtitle: 'Activate the floating overlay when you are ready to browse',
        ),
        OnboardingFeaturePoint(
          icon: Icons.stop_circle_outlined,
          title: 'Stop controls whenever you want',
          subtitle: 'Instant pause or stop button for complete autonomy',
        ),
      ],
    ),

    // Page 3: Privacy First
    OnboardingPageModel(
      index: 2,
      title: 'Your Device. Your Control.',
      description: 'Your privacy and control matter.',
      featurePoints: [
        OnboardingFeaturePoint(
          icon: Icons.no_accounts_rounded,
          title: 'No account registration required',
          subtitle: 'Start immediately without logins, passwords, or personal profiles',
        ),
        OnboardingFeaturePoint(
          icon: Icons.storage_rounded,
          title: 'Custom commands are stored locally',
          subtitle: 'Your trigger preferences never leave your device storage',
        ),
        OnboardingFeaturePoint(
          icon: Icons.verified_user_rounded,
          title: 'Permissions requested only when needed',
          subtitle: 'Microphone and camera access are prompted strictly upon session start',
        ),
        OnboardingFeaturePoint(
          icon: Icons.lock_clock_rounded,
          title: 'Actions restricted to an active Reel Session',
          subtitle: 'Background detection is completely dormant when the session ends',
        ),
        OnboardingFeaturePoint(
          icon: Icons.phonelink_setup_rounded,
          title: 'On-device speech recognition service',
          subtitle: 'Offline recognition depends on device and language model support. Android speech recognition may depend on the installed recognition service.',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await _storageService.setCompletedOnboarding(completed: true);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
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

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onSkip() {
    _completeOnboarding();
  }

  void _onIndicatorTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPage > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Instagram Reels Mobile Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/onboarding_bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Deep Dark Scrim Overlay for crisp readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0.90),
                      AppColors.background.withValues(alpha: 0.82),
                      AppColors.background.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),

            // Foreground Content
            SafeArea(
              child: Column(
                children: [
                  // Top Bar with Brand Badge and Skip action (pages 0 & 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand Badge
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryPurple.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/splashscreenimg.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'ReelSense',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),

                        // Top Skip shortcut on Page 0 and 1
                        if (_currentPage < _pages.length - 1)
                          TextButton(
                            onPressed: _onSkip,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // Horizontal Swipeable PageView
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return OnboardingPage(model: _pages[index]);
                      },
                    ),
                  ),

                  // Bottom Navigation bar
                  OnboardingNavigation(
                    currentPage: _currentPage,
                    totalPages: _pages.length,
                    onNext: _onNext,
                    onSkip: _onSkip,
                    onGetStarted: _completeOnboarding,
                    onIndicatorTap: _onIndicatorTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

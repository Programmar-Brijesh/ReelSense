import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AnimatedReelCards extends StatelessWidget {
  final Animation<Offset> slideAnimation;
  final Animation<double> fadeAnimation;
  final Animation<double> playScaleAnimation;
  final Animation<double> playGlowAnimation;
  final Animation<double> controlIndicatorsFade;
  final Animation<double> controlIndicatorsScale;

  const AnimatedReelCards({
    super.key,
    required this.slideAnimation,
    required this.fadeAnimation,
    required this.playScaleAnimation,
    required this.playGlowAnimation,
    required this.controlIndicatorsFade,
    required this.controlIndicatorsScale,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: SizedBox(
          width: 260,
          height: 190,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Background trailing Reel card (scrolling behind)
              Positioned(
                top: -24,
                child: Opacity(
                  opacity: 0.40,
                  child: Container(
                    width: 200,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // Main active Reel card
              Container(
                width: 220,
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1F35), Color(0xFF121324)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.25),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Simulated mini Reel UI (side action buttons)
                    Positioned(
                      right: 4,
                      top: 12,
                      bottom: 12,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          Icon(
                            Icons.share_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),

                    // Central Animated Play Symbol
                    Center(
                      child: AnimatedBuilder(
                        animation: playGlowAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentCyan.withValues(
                                    alpha: 0.35 * playGlowAnimation.value,
                                  ),
                                  blurRadius: 18 * playGlowAnimation.value,
                                  spreadRadius: 2 * playGlowAnimation.value,
                                ),
                              ],
                            ),
                            child: ScaleTransition(
                              scale: playScaleAnimation,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.primaryGradient,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom mini progress line
                    Positioned(
                      left: 6,
                      right: 32,
                      bottom: 2,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Microphone Sound Waves Badge (Left)
              Positioned(
                left: -8,
                bottom: 8,
                child: FadeTransition(
                  opacity: controlIndicatorsFade,
                  child: ScaleTransition(
                    scale: controlIndicatorsScale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground.withValues(
                          alpha: 0.95,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mic_rounded,
                            color: AppColors.accentCyan,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          _buildWaveformBars(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Hand Gesture Indicator Badge (Right)
              Positioned(
                right: -8,
                top: 14,
                child: FadeTransition(
                  opacity: controlIndicatorsFade,
                  child: ScaleTransition(
                    scale: controlIndicatorsScale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground.withValues(
                          alpha: 0.95,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryPurple.withValues(alpha: 0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPurple.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pan_tool_alt_rounded,
                            color: AppColors.primaryPurple,
                            size: 15,
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_double_arrow_up_rounded,
                            color: AppColors.textPrimary,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveformBars() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WaveBar(height: 8),
        SizedBox(width: 2),
        _WaveBar(height: 14),
        SizedBox(width: 2),
        _WaveBar(height: 10),
        SizedBox(width: 2),
        _WaveBar(height: 16),
      ],
    );
  }
}

class _WaveBar extends StatelessWidget {
  final double height;
  const _WaveBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.accentCyan,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

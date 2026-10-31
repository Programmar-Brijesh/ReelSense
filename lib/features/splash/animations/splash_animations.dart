import 'package:flutter/material.dart';

class SplashAnimations {
  final AnimationController controller;

  late final Animation<double> ambientOpacity;
  late final Animation<double> logoFade;
  late final Animation<double> logoScale;
  late final Animation<double> wordmarkFade;
  late final Animation<Offset> wordmarkSlide;
  late final Animation<double> taglineFade;
  late final Animation<Offset> taglineSlide;
  late final Animation<double> footerFade;
  late final Animation<Offset> footerSlide;

  SplashAnimations(this.controller) {
    // 1. Ambient lighting (0.0 - 0.40)
    ambientOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    // 2. Logo fade & scale (0.10 - 0.50)
    logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.10, 0.50, curve: Curves.easeOut),
      ),
    );
    logoScale = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.10, 0.55, curve: Curves.easeOutBack),
      ),
    );

    // 3. Wordmark reveal (0.45 - 0.75)
    wordmarkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeIn),
      ),
    );
    wordmarkSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Tagline reveal (0.60 - 0.85)
    taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeIn),
      ),
    );
    taglineSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Developer footer reveal (0.70 - 0.95)
    footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.70, 0.95, curve: Curves.easeIn),
      ),
    );
    footerSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.70, 0.95, curve: Curves.easeOutCubic),
      ),
    );
  }
}

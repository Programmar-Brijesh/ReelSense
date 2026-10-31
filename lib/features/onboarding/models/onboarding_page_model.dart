import 'package:flutter/material.dart';

class OnboardingFeaturePoint {
  final IconData icon;
  final String title;
  final String? subtitle;

  const OnboardingFeaturePoint({
    required this.icon,
    required this.title,
    this.subtitle,
  });
}

class OnboardingPageModel {
  final int index;
  final String title;
  final String description;
  final List<OnboardingFeaturePoint> featurePoints;

  const OnboardingPageModel({
    required this.index,
    required this.title,
    required this.description,
    required this.featurePoints,
  });
}

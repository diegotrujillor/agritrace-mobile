import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/constants.dart';

/// Brand mark variants available in the asset bundle.
///
/// - [mark]: full-colour mark intended for light backgrounds.
/// - [white]: mono-white mark for use on the primary-green hero surfaces
///   (e.g. WelcomeScreen).
enum AppLogoVariant { mark, white }

/// Reusable AgriTrace brand mark.
///
/// v1.9.2 — QA cycle-01: addresses "logos missing" on 7 screens. Renders
/// the SVG mark at the requested [size]. Pass an optional [color] to tint
/// the mark; when set it overrides the SVG fill via a [ColorFilter] in
/// `srcIn` mode. Most callers leave it `null` so the source colours are
/// preserved.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = 32,
    this.color,
    this.variant = AppLogoVariant.mark,
  });

  final double size;
  final Color? color;
  final AppLogoVariant variant;

  String get _asset {
    switch (variant) {
      case AppLogoVariant.mark:
        return 'assets/brand/agritrace-logo-mark.svg';
      case AppLogoVariant.white:
        return 'assets/brand/agritrace-logo-white.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _asset,
      width: size,
      height: size,
      semanticsLabel: 'AgriTrace',
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}

/// Convenience wrapper that pins an [AppLogoMark] to the bottom-left of
/// its parent with [AppSpacing.md] padding — the standard placement used
/// on form screens per QA cycle-01 (#13, #19, #22).
class BottomLeftLogo extends StatelessWidget {
  const BottomLeftLogo({
    super.key,
    this.size = 40,
    this.variant = AppLogoVariant.mark,
  });

  final double size;
  final AppLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: AppLogoMark(size: size, variant: variant),
      ),
    );
  }
}

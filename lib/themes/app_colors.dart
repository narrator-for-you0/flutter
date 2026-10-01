import 'package:flutter/material.dart';

import '../models/expense_category.dart';

/// Light/dark colour palette used by every screen.
///
/// Light values are the app's original colours, so light mode looks exactly as before.
/// Call [AppColors.sync] at the top of a widget's `build` so it repaints when the
/// theme flips, then read colours as `AppColors.text`, `AppColors.card`, etc.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static bool get isDark => _dark;

  /// Reads the active brightness (and registers a dependency on the Theme so the
  /// calling widget rebuilds when light/dark changes).
  static void sync(BuildContext context) {
    _dark = Theme.of(context).brightness == Brightness.dark;
  }

  static Color _p(int light, int dark) => Color(_dark ? dark : light);

  static Color get bg => _p(0xFFFFFFFF, 0xFF0F172A);
  static Color get bgAlt => _p(0xFFF7F9FC, 0xFF0F172A);
  static Color get surface => _p(0xFFFFFFFF, 0xFF1B2538);
  static Color get card => _p(0xFFF8FAFC, 0xFF243147);
  static Color get cardAlt => _p(0xFFF9F9F9, 0xFF243147);
  static Color get fill => _p(0xFFF1F5F9, 0xFF2D3B52);
  static Color get border => _p(0xFFF1F5F9, 0xFF334155);
  static Color get borderAlt => _p(0xFFEFEFEF, 0xFF334155);
  static Color get track => _p(0xFFE2E8F0, 0xFF334155);
  static Color get trackAlt => _p(0xFFE0E0E0, 0xFF334155);
  static Color get trackDisabled => _p(0xFFCBD5E1, 0xFF334155);
  static Color get text => _p(0xFF1E293B, 0xFFF1F5F9);
  static Color get text2 => _p(0xFF334155, 0xFFCBD5E1);
  static Color get muted => _p(0xFF64748B, 0xFF94A3B8);
  static Color get faint => _p(0xFF94A3B8, 0xFF7C8BA1);
  static Color get greyText => _p(0xFF9E9E9E, 0xFF94A3B8);
  static Color get greyBorder => _p(0xFFE0E0E0, 0xFF334155);
  static Color get strongText => _p(0xFF000000, 0xFFF1F5F9);
  static Color get greenSoft => _p(0xFFDCFCE7, 0xFF16382A);
  static Color get greenSoftAlt => _p(0xFFE8F5E9, 0xFF16382A);
  static Color get greenFaint => _p(0xFFF0FDF4, 0xFF12301F);
  static Color get greenDark => _p(0xFF15803D, 0xFF4ADE80);
  static Color get greenDeep => _p(0xFF166534, 0xFF86EFAC);
  static Color get greenBorder => _p(0xFF86EFAC, 0xFF166534);
  static Color get redSoft => _p(0xFFFEF2F2, 0xFF3A1D22);
  static Color get redSoft2 => _p(0xFFFEE2E2, 0xFF4A2226);
  static Color get redBorder => _p(0xFFFECACA, 0xFF7F2B30);
  static Color get blueSoft => _p(0xFFEFF6FF, 0xFF1B2B4A);
  static Color get blue => _p(0xFF2563EB, 0xFF60A5FA);
  static Color get amberSoft => _p(0xFFFFF8E1, 0xFF3A2F14);
  static Color get amberSoft2 => _p(0xFFFFFDE7, 0xFF3A2F14);
  static Color get amberSoft3 => _p(0xFFFEF3C7, 0xFF3A2F14);
  static Color get orangeSoft => _p(0xFFFFF7ED, 0xFF3A2616);
  static Color get orangeBorder => _p(0xFFFED7AA, 0xFF7C4A1E);
  static Color get amberText => _p(0xFFB45309, 0xFFFBBF24);
  static Color get orangeText => _p(0xFF9A3412, 0xFFFDBA74);
  static Color get goldText => _p(0xFFCA8A04, 0xFFFACC15);
  static Color get orangeAccent => _p(0xFFEA580C, 0xFFFB923C);
  static Color get black87 => _p(0xDD000000, 0xFFF1F5F9);
  static Color get black54 => _p(0x8A000000, 0xFF94A3B8);
  static Color get black45 => _p(0x73000000, 0xFF7C8BA1);
  static Color get tooltipBg => _p(0xFF0F172A, 0xFF334155);
}

extension ExpenseTypeTint on ExpenseType {
  /// Soft background tint for this type: the original pastel in light mode, a
  /// translucent wash of the accent colour in dark mode.
  Color get softBg => AppColors.isDark ? color.withValues(alpha: 0.16) : softColor;
}
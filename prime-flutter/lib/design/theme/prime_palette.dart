import 'package:flutter/material.dart';

/// Raw color ramps for PRIME. Brand purple is preserved verbatim.
///
/// Prefer [PrimeColors] semantic roles in UI — this palette is the source
/// of truth for building dark/light theme extensions.
abstract final class PrimePalette {
  // ── Brand (unchanged) ────────────────────────────────────────────────────
  static const brand = Color(0xFF8B5CF6);
  static const brandBright = Color(0xFF9B6CFF);
  static const brandDeep = Color(0xFF6D28D9);
  static const brandSoft = Color(0xFFC4B5FD);
  static const brandContainerDark = Color(0xFF352550);
  static const brandContainerLight = Color(0xFFDDD5FF);
  static const lavender = Color(0xFFD8CCF5);
  static const mist = Color(0xFFF4F0FF);
  static const softLilac = Color(0xFFE8E0F5);
  static const mutedViolet = Color(0xFF7C6B96);
  static const purpleGrey = Color(0xFF5C5468);
  static const premiumDarkViolet = Color(0xFF3D2A5C);

  // ── Dark neutrals (V4) ───────────────────────────────────────────────────
  static const darkCanvas = Color(0xFF0F0D14);
  static const darkCanvasSubtle = Color(0xFF12101A);
  static const darkSurface = Color(0xFF17141F);
  static const darkSurfaceElevated = Color(0xFF211C2B);
  static const darkSurfaceSoft = Color(0xFF292331);
  static const darkSurfaceSelected = Color(0xFF2E2442);
  static const darkDeep = Color(0xFF16131F);
  static const darkHeroStart = Color(0xFF2A1F3D);
  static const darkHeroEnd = Color(0xFF1A1528);
  static const darkInk = Color(0xFFF7F4FB);
  static const darkInkSecondary = Color(0xFFAAA2B4);
  static const darkInkMuted = Color(0xFF8E8799);
  static const darkHairline = Color(0x1FFFFFFF);
  static const darkHairlineStrong = Color(0x33FFFFFF);
  static const darkBubbleOut = Color(0xFF2A2140);
  static const darkBubbleIn = Color(0xFF1E1B26);

  // ── Light neutrals (designed independently, not inverted) ────────────────
  static const lightCanvas = Color(0xFFF8F7FA);
  static const lightCanvasSubtle = Color(0xFFF1EFF5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFFFFFFF);
  static const lightSurfaceSoft = Color(0xFFF1EFF5);
  static const lightSurfaceSelected = Color(0xFFDDD5FF);
  static const lightInk = Color(0xFF1A1622);
  static const lightInkSecondary = Color(0xFF6B6578);
  static const lightInkMuted = Color(0xFF8E8799);
  static const lightHairline = Color(0x141A1622);
  static const lightHairlineStrong = Color(0x291A1622);
  static const lightBubbleOut = Color(0xFFEDE7FF);
  static const lightBubbleIn = Color(0xFFF1EFF5);

  // ── Shared ───────────────────────────────────────────────────────────────
  static const inkOnBrand = Color(0xFFF8F7FA);
  static const disabled = Color(0xFF6B6578);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const success = Color(0xFF34D399);
  static const successMuted = Color(0xFF69B99A);
  static const warning = Color(0xFFFBBF24);
  static const warningMuted = Color(0xFFE8B85C);
  static const error = Color(0xFFF87171);
  static const errorMuted = Color(0xFFE86F78);
  static const info = Color(0xFF60A5FA);
  static const infoMuted = Color(0xFF6F9DE8);

  static const mint = Color(0xFF5EEAD4);
  static const focusBlue = Color(0xFF7DD3FC);
  static const achievementAmber = Color(0xFFFCD34D);
  static const coral = Color(0xFFFB7185);

  // ── Gold (achievements, rare) ────────────────────────────────────────────
  static const gold = Color(0xFFE4C56A);
  static const goldBright = Color(0xFFF0D78A);
  static const goldDeep = Color(0xFF9A7428);

  // ── Habit accents ────────────────────────────────────────────────────────
  static const habitSleep = Color(0xFF64748B);
  static const habitCharge = Color(0xFFD97706);
  static const habitRead = Color(0xFF94A3B8);
  static const habitFocus = Color(0xFF8B5CF6);
  static const habitSocial = Color(0xFFA78BFA);
  static const habitDetox = Color(0xFF6366F1);
}

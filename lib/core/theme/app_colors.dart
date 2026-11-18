import 'package:material_ui/material_ui.dart';

/// Fantasy-jungle palette shared by the whole app.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color jungleDeep = Color(0xFF0B2A1E);
  static const Color jungleDark = Color(0xFF143D2B);
  static const Color jungleMid = Color(0xFF1F6B45);
  static const Color jungleLight = Color(0xFF3FA66B);

  // Accents
  static const Color gold = Color(0xFFFFC857);
  static const Color goldDark = Color(0xFFD99A1E);
  static const Color sunset = Color(0xFFFF7A59);
  static const Color cream = Color(0xFFFFF4D6);
  static const Color wood = Color(0xFF8C5A2B);
  static const Color woodDark = Color(0xFF5A3617);

  // Board cells
  static const Color cellA = Color(0xFFF4E9C8);
  static const Color cellB = Color(0xFFCFE8C6);
  static const Color cellBorder = Color(0xFF2E5B3E);
  static const Color cellNumber = Color(0xFF28412F);
  static const Color cellFinal = Color(0xFFFFD873);

  /// Token colours in player order.
  static const List<Color> players = [
    Color(0xFFE53950), // red
    Color(0xFF2F80ED), // blue
    Color(0xFFF2C94C), // yellow
    Color(0xFF27AE60), // green
  ];

  /// Body / belly colour pairs for snakes.
  static const List<(Color, Color)> snakes = [
    (Color(0xFF2E8B57), Color(0xFFB7E4A3)),
    (Color(0xFF7B3FE4), Color(0xFFD9C2FF)),
    (Color(0xFFE2543B), Color(0xFFFFD2B0)),
    (Color(0xFF1E88E5), Color(0xFFB3E5FC)),
    (Color(0xFFD4A017), Color(0xFFFFF1B8)),
    (Color(0xFF8E24AA), Color(0xFFF3C5FF)),
  ];
}

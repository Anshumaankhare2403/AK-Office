import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'DocuCraft';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Offline Professional Document Editor with AI Assistant';

  // Storage Folders
  static const String rootFolderName = 'DocuCraft';
  static const String documentsFolder = 'Documents';
  static const String revisionsFolder = 'Revisions';
  static const String draftsFolder = 'Drafts';
  static const String modelsFolder = 'Models';

  // File Extensions
  static const String docExtension = '.docucraft';
  static const String docxExtension = '.docx';
  static const String pdfExtension = '.pdf';
  static const String txtExtension = '.txt';

  // Default Page Settings
  static const double defaultMarginPoints = 72.0; // 1 inch = 72 pt
  static const double a4WidthPoints = 595.28;
  static const double a4HeightPoints = 841.89;
  static const double letterWidthPoints = 612.0;
  static const double letterHeightPoints = 792.0;
  static const double legalWidthPoints = 612.0;
  static const double legalHeightPoints = 1008.0;

  // Colors inspired by Microsoft Office / Fluent design
  static const Color wordBlue = Color(0xFF0F6CBD);
  static const Color wordDarkBlue = Color(0xFF115EA3);
  static const Color wordLightBlue = Color(0xFFEBF3FC);
  static const Color ribbonBackgroundLight = Color(0xFFF3F5F8);
  static const Color ribbonBackgroundDark = Color(0xFF202020);
  static const Color paperBackgroundLight = Colors.white;
  static const Color canvasBackgroundLight = Color(0xFFE6E8EC);
  static const Color canvasBackgroundDark = Color(0xFF181818);
  static const Color textPrimaryLight = Color(0xFF242424);
  static const Color textSecondaryLight = Color(0xFF616161);

  // Autosave delay in milliseconds
  static const int autosaveDebounceMs = 1500;
}

import 'dart:convert';
import '../core/constants/app_constants.dart';

enum PageFormatType { a4, letter, legal }

enum PageOrientationType { portrait, landscape }

class PageSettingsModel {
  final PageFormatType format;
  final PageOrientationType orientation;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final bool showPageNumbers;
  final String? headerText;
  final String? footerText;

  const PageSettingsModel({
    this.format = PageFormatType.a4,
    this.orientation = PageOrientationType.portrait,
    this.marginTop = AppConstants.defaultMarginPoints,
    this.marginBottom = AppConstants.defaultMarginPoints,
    this.marginLeft = AppConstants.defaultMarginPoints,
    this.marginRight = AppConstants.defaultMarginPoints,
    this.showPageNumbers = true,
    this.headerText,
    this.footerText,
  });

  double get _baseWidth {
    switch (format) {
      case PageFormatType.a4:
        return AppConstants.a4WidthPoints;
      case PageFormatType.letter:
        return AppConstants.letterWidthPoints;
      case PageFormatType.legal:
        return AppConstants.legalWidthPoints;
    }
  }

  double get _baseHeight {
    switch (format) {
      case PageFormatType.a4:
        return AppConstants.a4HeightPoints;
      case PageFormatType.letter:
        return AppConstants.letterHeightPoints;
      case PageFormatType.legal:
        return AppConstants.legalHeightPoints;
    }
  }

  double get width => orientation == PageOrientationType.portrait ? _baseWidth : _baseHeight;

  double get height => orientation == PageOrientationType.portrait ? _baseHeight : _baseWidth;

  PageSettingsModel copyWith({
    PageFormatType? format,
    PageOrientationType? orientation,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    bool? showPageNumbers,
    String? headerText,
    String? footerText,
  }) {
    return PageSettingsModel(
      format: format ?? this.format,
      orientation: orientation ?? this.orientation,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'format': format.name,
      'orientation': orientation.name,
      'marginTop': marginTop,
      'marginBottom': marginBottom,
      'marginLeft': marginLeft,
      'marginRight': marginRight,
      'showPageNumbers': showPageNumbers,
      'headerText': headerText,
      'footerText': footerText,
    };
  }

  factory PageSettingsModel.fromMap(Map<String, dynamic> map) {
    return PageSettingsModel(
      format: PageFormatType.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => PageFormatType.a4,
      ),
      orientation: PageOrientationType.values.firstWhere(
        (e) => e.name == map['orientation'],
        orElse: () => PageOrientationType.portrait,
      ),
      marginTop: (map['marginTop'] as num?)?.toDouble() ?? AppConstants.defaultMarginPoints,
      marginBottom: (map['marginBottom'] as num?)?.toDouble() ?? AppConstants.defaultMarginPoints,
      marginLeft: (map['marginLeft'] as num?)?.toDouble() ?? AppConstants.defaultMarginPoints,
      marginRight: (map['marginRight'] as num?)?.toDouble() ?? AppConstants.defaultMarginPoints,
      showPageNumbers: map['showPageNumbers'] as bool? ?? true,
      headerText: map['headerText'] as String?,
      footerText: map['footerText'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PageSettingsModel.fromJson(String source) =>
      PageSettingsModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

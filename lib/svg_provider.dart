import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// Get svg string.
typedef SvgStringGetter = Future<String?> Function(SvgImageKey key);

/// An [Enum] of the possible image path sources.
enum SvgSource {
  /// Load SVG from a file on the device
  file,

  /// Load SVG from application assets
  asset,

  /// Load SVG from a network URL
  network,

  /// Load SVG from another package's assets
  package,

  /// Use a raw SVG string directly
  raw,
}

/// Configuration options for SVG validation
///
/// Use [SvgValidationOptions.none], [SvgValidationOptions.basic], or
/// [SvgValidationOptions.strict] for preset configurations, or create
/// a custom configuration.
///
/// Example:
/// ```dart
/// // Custom validation
/// final options = SvgValidationOptions(
///   validateStructure: true,
///   validateViewBox: true,
///   validateDimensions: true,
///   maxDimension: 1000,
///   minDimension: 10,
/// );
/// ```
class SvgValidationOptions {
  /// Whether to perform structure validation (tags, namespace, etc.)
  final bool validateStructure;

  /// Whether to validate viewBox attribute
  final bool validateViewBox;

  /// Whether to check for reasonable size dimensions
  final bool validateDimensions;

  /// Whether to check for malformed attributes
  final bool validateAttributes;

  /// Whether to check for unsupported elements
  final bool validateElements;

  /// Maximum allowed dimension value
  final double maxDimension;

  /// Minimum allowed dimension value
  final double minDimension;

  const SvgValidationOptions({
    this.validateStructure = true,
    this.validateViewBox = true,
    this.validateDimensions = true,
    this.validateAttributes = true,
    this.validateElements = true,
    this.maxDimension = 10000,
    this.minDimension = 0,
  });

  /// No validation checks
  static const none = SvgValidationOptions(
    validateStructure: false,
    validateViewBox: false,
    validateDimensions: false,
    validateAttributes: false,
    validateElements: false,
  );

  /// Basic validation only (structure)
  static const basic = SvgValidationOptions(
    validateStructure: true,
    validateViewBox: false,
    validateDimensions: false,
    validateAttributes: false,
    validateElements: false,
  );

  /// Full validation with all checks
  static const strict = SvgValidationOptions(
    validateStructure: true,
    validateViewBox: true,
    validateDimensions: true,
    validateAttributes: true,
    validateElements: true,
  );
}

/// Validates SVG content with configurable options
class SvgValidator {
  final SvgValidationOptions options;

  /// Set of supported SVG elements
  static const supportedElements = {
    'svg',
    'path',
    'rect',
    'circle',
    'ellipse',
    'line',
    'polyline',
    'polygon',
    'text',
    'g',
    'defs',
    'use',
    'symbol',
    'clipPath',
    'mask',
    'linearGradient',
    'radialGradient',
    'stop',
    'filter',
    'feGaussianBlur',
    'feOffset',
    'feBlend',
    'feColorMatrix',
  };

  const SvgValidator([this.options = const SvgValidationOptions()]);

  /// Validates SVG string based on configured options
  void validate(String svg) {
    final trimmed = svg.trim();

    if (trimmed.isEmpty) {
      throw ArgumentError('SVG string cannot be empty');
    }

    if (options.validateStructure) {
      _validateStructure(trimmed);
    }

    if (options.validateViewBox) {
      _validateViewBox(trimmed);
    }

    if (options.validateDimensions) {
      _validateDimensions(trimmed);
    }

    if (options.validateAttributes) {
      _validateAttributes(trimmed);
    }

    if (options.validateElements) {
      _validateElements(trimmed);
    }
  }

  void _validateStructure(String svg) {
    if (!svg.contains(RegExp(r'<svg[^>]*>'))) {
      throw ArgumentError('Missing <svg> tag');
    }

    if (!svg.contains('xmlns="http://www.w3.org/2000/svg"')) {
      throw ArgumentError('Missing SVG namespace declaration');
    }

    final openTags = RegExp(r'<[^/][^>]*>').allMatches(svg).length;
    final closeTags = RegExp(r'</[^>]*>').allMatches(svg).length;
    final selfClosingTags = RegExp(r'<[^>]*/\s*>').allMatches(svg).length;

    if (openTags - selfClosingTags != closeTags) {
      throw ArgumentError('Unbalanced SVG tags');
    }

    final hasContent = RegExp(
      r'<(path|rect|circle|ellipse|line|polyline|polygon|text|g)[^>]*>',
    ).hasMatch(svg);

    if (!hasContent) {
      throw ArgumentError('SVG lacks valid content elements');
    }
  }

  void _validateViewBox(String svg) {
    final viewBoxMatch = RegExp(r'''viewBox=["\']([-\d\.\s]+)["\']''').firstMatch(svg);

    if (viewBoxMatch == null) {
      throw ArgumentError('Missing viewBox attribute');
    }

    final values = viewBoxMatch.group(1)!.split(RegExp(r'[\s,]+')).map(double.parse).toList();

    if (values.length != 4) {
      throw ArgumentError('Invalid viewBox format');
    }

    if (values[2] <= 0 || values[3] <= 0) {
      throw ArgumentError('Invalid viewBox dimensions');
    }
  }

  void _validateDimensions(String svg) {
    final widthMatch = RegExp(r'''width=["\']([\d\.]+)([a-z%]*)["\'"]''').firstMatch(svg);

    final heightMatch = RegExp(r'''height=["\']([\d\.]+)([a-z%]*)["\'"]''').firstMatch(svg);

    if (widthMatch != null) {
      final width = double.parse(widthMatch.group(1)!);
      if (width < options.minDimension || width > options.maxDimension) {
        throw ArgumentError('Width dimension out of allowed range');
      }
    }

    if (heightMatch != null) {
      final height = double.parse(heightMatch.group(1)!);
      if (height < options.minDimension || height > options.maxDimension) {
        throw ArgumentError('Height dimension out of allowed range');
      }
    }
  }

  void _validateAttributes(String svg) {
    final styleMatches = RegExp(r'''style=["\'](.*?)["\']''').allMatches(svg);
    for (final match in styleMatches) {
      final style = match.group(1)!;
      if (!RegExp(
        r'''^[-a-zA-Z]+[-a-zA-Z0-9]*:\s*[^;]+(?:\s*;\s*[-a-zA-Z]+[-a-zA-Z0-9]*:\s*[^;]+)*$''',
      ).hasMatch(style)) {
        throw ArgumentError('Malformed style attribute: $style');
      }
    }

    final transformMatches = RegExp(r'''transform=["\'](.*?)["\']''').allMatches(svg);

    for (final match in transformMatches) {
      final transform = match.group(1)!;
      if (!RegExp(r'''^[a-zA-Z]+\([^)]+\)(?:\s+[a-zA-Z]+\([^)]+\))*$''').hasMatch(transform)) {
        throw ArgumentError('Malformed transform attribute: $transform');
      }
    }
  }

  void _validateElements(String svg) {
    final elementMatches = RegExp(r'<(\w+)[^>]*>').allMatches(svg);
    for (final match in elementMatches) {
      final element = match.group(1)!.toLowerCase();
      if (!supportedElements.contains(element)) {
        throw ArgumentError('Unsupported SVG element: $element');
      }
    }
  }
}

/// Rasterizes SVG images for displaying in [Image] widget with support for
/// multiple sources and validation options.
///
/// Examples:
/// ```dart
/// // From assets
/// Image(
///   width: 32,
///   height: 32,
///   image: SvgProvider('assets/my_icon.svg'),
/// )
///
/// // From network with validation
/// Image(
///   width: 32,
///   height: 32,
///   image: SvgProvider(
///     'https://example.com/icon.svg',
///     source: SvgSource.network,
///     validationOptions: SvgValidationOptions.strict,
///   ),
/// )
///
/// // From package with custom validation
/// Image(
///   width: 32,
///   height: 32,
///   image: SvgProvider(
///     'assets/icons/my_icon.svg',
///     source: SvgSource.package,
///     package: 'my_package',
///     validationOptions: SvgValidationOptions(
///       validateStructure: true,
///       validateViewBox: true,
///       maxDimension: 1000,
///     ),
///   ),
/// )
///
/// // From raw SVG string
/// Image(
///   width: 32,
///   height: 32,
///   image: SvgProvider(
///     '''<svg xmlns="http://www.w3.org/2000/svg" ...></svg>''',
///     source: SvgSource.raw,
///     validationOptions: SvgValidationOptions.basic,
///   ),
/// )
/// ```
class SvgProvider extends ImageProvider<SvgImageKey> {
  /// Path to svg file or asset, URL for network sources,
  /// or raw SVG string for [SvgSource.raw]
  final String path;

  /// Size in logical pixels to render.
  /// Useful for [DecorationImage].
  /// If not specified, will use size from [Image].
  /// If [Image] not specifies size too, will use default size 100x100.
  final Size? size;

  /// Color to tint the SVG
  final Color? color;

  /// Source of svg image
  final SvgSource source;

  /// Image scale.
  final double? scale;

  /// Get svg string.
  /// Override the default get method.
  /// When returning null, use the default method.
  final SvgStringGetter? svgGetter;

  /// The package name when using [SvgSource.package].
  /// For example: 'my_package'
  final String? package;

  /// SVG validation options
  final SvgValidationOptions? validationOptions;

  const SvgProvider(
    this.path, {
    this.size,
    this.scale,
    this.color,
    this.source = SvgSource.asset,
    this.svgGetter,
    this.package,
    this.validationOptions,
  });

  @override
  Future<SvgImageKey> obtainKey(ImageConfiguration configuration) {
    final color = this.color ?? Colors.transparent;
    final scale = this.scale ?? configuration.devicePixelRatio ?? 1.0;

    final logicalWidth = size?.width ?? configuration.size?.width ?? 100;
    final logicalHeight = size?.height ?? configuration.size?.height ?? 100;

    final pixelWidth = (logicalWidth * scale).round();
    final pixelHeight = (logicalHeight * scale).round();

    return SynchronousFuture<SvgImageKey>(
      SvgImageKey(
        path: path,
        scale: scale,
        color: color,
        source: source,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
        svgGetter: svgGetter,
        package: package,
        validationOptions: validationOptions,
      ),
    );
  }

  @override
  ImageStreamCompleter loadImage(SvgImageKey key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync(key, getFilterColor(color)));
  }

  static Future<String> getSvgString(SvgImageKey key) async {
    final validator = key.validationOptions != null ? SvgValidator(key.validationOptions!) : null;

    Future<String> validateAndReturn(String svg) async {
      validator?.validate(svg);
      return svg;
    }

    try {
      if (key.svgGetter != null) {
        final rawSvg = await key.svgGetter!(key);
        if (rawSvg != null) {
          return await validateAndReturn(rawSvg);
        }
      }

      switch (key.source) {
        case SvgSource.network:
          try {
            final response = await http
                .get(Uri.parse(key.path))
                .timeout(const Duration(seconds: 10));
            if (response.statusCode != 200) {
              throw Exception('Failed to load network SVG. Status: ${response.statusCode}');
            }
            return await validateAndReturn(response.body);
          } on TimeoutException {
            throw Exception('Network SVG request timed out');
          } on http.ClientException catch (e) {
            throw Exception('Network SVG request failed: $e');
          }

        case SvgSource.asset:
          try {
            return await validateAndReturn(await rootBundle.loadString(key.path));
          } catch (e) {
            throw Exception('Failed to load asset SVG: $e');
          }

        case SvgSource.file:
          try {
            final file = File(key.path);
            if (!await file.exists()) {
              throw Exception('SVG file not found: ${key.path}');
            }
            return await validateAndReturn(await file.readAsString());
          } catch (e) {
            throw Exception('Failed to load SVG file: $e');
          }

        case SvgSource.package:
          if (key.package == null) {
            throw ArgumentError('Package parameter is required for SvgSource.package');
          }
          try {
            final packagePath = 'packages/${key.package}/${key.path}';
            return await validateAndReturn(await rootBundle.loadString(packagePath));
          } catch (e) {
            throw Exception('Failed to load package SVG from ${key.package}: $e');
          }

        case SvgSource.raw:
          try {
            return await validateAndReturn(key.path);
          } catch (e) {
            throw ArgumentError('Invalid SVG string: $e');
          }
      }
    } catch (e) {
      throw Exception('Failed to load SVG: $e');
    }
  }

  static Future<ImageInfo> _loadAsync(SvgImageKey key, Color color) async {
    final rawSvg = await getSvgString(key);

    try {
      final pictureInfo = await vg.loadPicture(
        SvgStringLoader(rawSvg, theme: SvgTheme(currentColor: color)),
        null,
        clipViewbox: false,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final scaleX = key.pixelWidth / pictureInfo.size.width;
      final scaleY = key.pixelHeight / pictureInfo.size.height;
      final scale = math.min(scaleX, scaleY);

      final dx = (key.pixelWidth - (pictureInfo.size.width * scale)) / 2;
      final dy = (key.pixelHeight - (pictureInfo.size.height * scale)) / 2;

      canvas.translate(dx, dy);
      canvas.scale(scale);
      canvas.drawPicture(pictureInfo.picture);

      final image = await recorder.endRecording().toImage(key.pixelWidth, key.pixelHeight);

      return ImageInfo(image: image, scale: 1.0);
    } catch (e) {
      throw Exception('Failed to render SVG: $e');
    }
  }

  @override
  String toString() => '$runtimeType(${describeIdentity(path)})';

  static Color getFilterColor(color) {
    if (kIsWeb && color == Colors.transparent) {
      return const Color(0x01ffffff);
    } else {
      return color ?? Colors.transparent;
    }
  }
}

@immutable
class SvgImageKey {
  const SvgImageKey({
    required this.path,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.scale,
    required this.source,
    this.color,
    this.svgGetter,
    this.package,
    this.validationOptions,
  });

  final String path;
  final int pixelWidth;
  final int pixelHeight;
  final Color? color;
  final SvgSource source;
  final double scale;
  final SvgStringGetter? svgGetter;
  final String? package;
  final SvgValidationOptions? validationOptions;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is SvgImageKey &&
        other.path == path &&
        other.pixelWidth == pixelWidth &&
        other.pixelHeight == pixelHeight &&
        other.scale == scale &&
        other.source == source &&
        other.svgGetter == svgGetter &&
        other.color == color &&
        other.package == package &&
        other.validationOptions == validationOptions;
  }

  @override
  int get hashCode => Object.hash(
    path,
    pixelWidth,
    pixelHeight,
    scale,
    source,
    svgGetter,
    color,
    package,
    validationOptions,
  );

  @override
  String toString() =>
      '${objectRuntimeType(this, 'SvgImageKey')}'
      '(path: "$path", pixelWidth: $pixelWidth, pixelHeight: $pixelHeight, '
      'color: $color, scale: $scale, source: $source, package: $package)';
}

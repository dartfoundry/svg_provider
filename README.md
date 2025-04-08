# SVG Provider

[![Pub](https://img.shields.io/pub/v/svg_provider.svg?style=flat-square)](https://pub.dartlang.org/packages/svg_provider)
[![Flutter Tests](https://github.com/dartfoundry/svg_provider/actions/workflows/flutter-tests.yml/badge.svg)](https://github.com/dartfoundry/svg_provider/actions/workflows/flutter-tests.yml)

A Flutter package for efficiently displaying SVG images in your application with support for multiple sources and validation options.

## Features

- Support for multiple SVG sources (assets, files, network, package, raw strings)
- Configurable validation options for SVG content
- Color tinting support
- Custom sizing control
- Error handling and detailed validation feedback

## Background

The [flutter_svg_provider](https://github.com/yang-f/flutter_svg_provider) package was created to bridge the gap between Flutter's Image widget and SVG files, using `flutter_svg` for parsing. While functional, the package had several **open unanswered issues** regarding image quality, particularly when rendering at different scales; and support for rendering SVGs from other packages.

### The Problem

The original package used a direct approach to convert SVGs to raster images:

```dart
final image = pictureInfo.picture.toImage(
  pictureInfo.size.width.round(),
  pictureInfo.size.height.round(),
);
```

This implementation, while straightforward, led to quality issues:
- Blurry/pixelated rendering
- Inconsistent sizing
- Poor scaling on high-DPI displays

### The Solution

The key to fixing these issues was to take control of the rendering process using Flutter's Canvas API. I also improved the package's functionality by adding raw svg string and package asset support, SVG markup validation, and cleaner error handling.

Read the following article to get an in-depth understanding of the solution: [Fixing SVG Rendering Quality in Flutter - A Deep Dive](https://djocubeit.medium.com/b857b3dc42ed).

## Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  svg_provider: ^1.0.0
```

## Usage

### Basic Usage

```dart
Image(
  width: 32,
  height: 32,
  image: SvgProvider('assets/my_icon.svg'),
);
```

### Advanced Usage

#### From Network with Validation

```dart
Image(
  width: 32,
  height: 32,
  image: SvgProvider(
    'https://example.com/icon.svg',
    source: SvgSource.network,
    validationOptions: SvgValidationOptions.strict,
  ),
);
```

#### Custom Validation Options

```dart
Image(
  width: 32,
  height: 32,
  image: SvgProvider(
    'assets/icons/my_icon.svg',
    validationOptions: SvgValidationOptions(
      validateStructure: true,
      validateViewBox: true,
      maxDimension: 1000,
    ),
  ),
);
```

#### From Package Assets

```dart
Image(
  width: 32,
  height: 32,
  image: SvgProvider(
    'assets/icons/my_icon.svg',
    source: SvgSource.package,
    package: 'my_package',
  ),
);
```

#### From Raw SVG String

```dart
Image(
  width: 32,
  height: 32,
  image: SvgProvider(
    '''<svg xmlns="http://www.w3.org/2000/svg" ...></svg>''',
    source: SvgSource.raw,
  ),
);
```

## API Reference

### SvgProvider

`SvgProvider` is an implementation of Flutter's `ImageProvider` that renders SVG images from various sources.

#### Constructor

```dart
const SvgProvider(
  String path, {
  Size? size,
  double? scale,
  Color? color,
  SvgSource source = SvgSource.asset,
  SvgStringGetter? svgGetter,
  String? package,
  SvgValidationOptions? validationOptions,
});
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `String` | Path to SVG file or asset, URL for network sources, or raw SVG string for `SvgSource.raw` |
| `size` | `Size?` | Size in logical pixels to render. Useful for `DecorationImage`. If not specified, will use size from `Image`. If `Image` does not specify size either, will use default size 100x100. |
| `scale` | `double?` | Image scale factor relative to the pixel density of the display |
| `color` | `Color?` | Color to tint the SVG |
| `source` | `SvgSource` | Source type of the SVG image. Defaults to `SvgSource.asset`. |
| `svgGetter` | `SvgStringGetter?` | Optional custom function to retrieve the SVG string |
| `package` | `String?` | The package name when using `SvgSource.package` |
| `validationOptions` | `SvgValidationOptions?` | Optional configuration for SVG validation |

#### Methods

| Method | Description |
|--------|-------------|
| `obtainKey` | Creates an `SvgImageKey` based on the provider's configuration |
| `loadImage` | Loads the image from the SVG content |
| `getSvgString` | Static utility method to retrieve the SVG content string |
| `getFilterColor` | Resolves the appropriate filter color |

### SvgSource

Enum defining possible image path sources:
- `SvgSource.file` - Load SVG from a file on the device
- `SvgSource.asset` - Load SVG from application assets
- `SvgSource.network` - Load SVG from a network URL
- `SvgSource.package` - Load SVG from another package's assets
- `SvgSource.raw` - Use a raw SVG string directly

### SvgValidationOptions

Configuration options for SVG validation with preset configurations for different validation levels.

#### Constructor

```dart
const SvgValidationOptions({
  bool validateStructure = true,
  bool validateViewBox = true,
  bool validateDimensions = true,
  bool validateAttributes = true,
  bool validateElements = true,
  double maxDimension = 10000,
  double minDimension = 0,
});
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validateStructure` | `bool` | `true` | Whether to perform structure validation (tags, namespace, etc.) |
| `validateViewBox` | `bool` | `true` | Whether to validate viewBox attribute |
| `validateDimensions` | `bool` | `true` | Whether to check for reasonable size dimensions |
| `validateAttributes` | `bool` | `true` | Whether to check for malformed attributes |
| `validateElements` | `bool` | `true` | Whether to check for unsupported elements |
| `maxDimension` | `double` | `10000` | Maximum allowed dimension value |
| `minDimension` | `double` | `0` | Minimum allowed dimension value |

#### Preset Configurations

- **`SvgValidationOptions.none`**: No validation checks
- **`SvgValidationOptions.basic`**: Basic validation only (structure)
- **`SvgValidationOptions.strict`**: Full validation with all checks

### SvgValidator

A utility class for validating SVG content with configurable options.

#### Validation Checks

1. **Structure Validation**: Checks for proper SVG structure, including:
   - Presence of `<svg>` tag
   - Correct namespace declaration
   - Balanced tags
   - Presence of content elements

2. **ViewBox Validation**: Ensures proper `viewBox` attribute format and values.

3. **Dimension Validation**: Validates width and height attributes against configured min/max values.

4. **Attribute Validation**: Checks for malformed style and transform attributes.

5. **Element Validation**: Verifies that all elements in the SVG are supported.

#### Supported Elements

The validator recognizes SVG elements including: svg, path, rect, circle, ellipse, line, polyline, polygon, text, g, defs, use, symbol, clipPath, mask, linearGradient, radialGradient, stop, filter, feGaussianBlur, feOffset, feBlend, feColorMatrix, and more.

### Example

```dart
final validator = SvgValidator(SvgValidationOptions.strict);

try {
  validator.validate(svgString);
  print('SVG is valid');
} catch (e) {
  print('SVG validation failed: $e');
}
```

## Copyright

Copyright (c) 2025 Dom Jocubeit

## License

Apache License, Version 2.0

## Testing

```sh
flutter test test/svg_provider_test.dart
```

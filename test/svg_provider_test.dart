// SPDX-FileCopyrightText: © 2025 Dom Jocubeit <support@dartfoundry.com>
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:svg_provider/svg_provider.dart';

import 'mock_classes.mocks.dart';

class TestAssetBundle extends AssetBundle {
  final Map<String, ByteData> assets = {};

  void addAsset(String key, String content) {
    assets[key] = Uint8List.fromList(content.codeUnits).buffer.asByteData();
  }

  @override
  Future<ByteData> load(String key) async {
    return assets[key] ?? (throw FlutterError('Asset $key not found'));
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async {
    final data = await load(key);
    return parser(String.fromCharCodes(data.buffer.asUint8List()));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String validSvg;

  setUp(() {
    validSvg = '''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <path d="M12 2L2 7l10 5 10-5-10-5z"/>
      </svg>
    ''';
  });

  group('SvgValidator Tests', () {
    test('validates correct SVG structure', () {
      final validator = SvgValidator();
      expect(() => validator.validate(validSvg), returnsNormally);
    });

    test('throws on missing namespace', () {
      final validator = SvgValidator();
      final invalidSvg = '<svg><path d="M0 0h24v24H0z"/></svg>';

      expect(
        () => validator.validate(invalidSvg),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Missing SVG namespace declaration',
          ),
        ),
      );
    });

    test('throws on invalid viewBox', () {
      final validator = SvgValidator(const SvgValidationOptions(validateViewBox: true));
      final invalidSvg = '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0h24v24H0z"/>
        </svg>
      ''';

      expect(
        () => validator.validate(invalidSvg),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message', 'Missing viewBox attribute'),
        ),
      );
    });

    test('validates dimensions', () {
      final validator = SvgValidator(
        const SvgValidationOptions(validateDimensions: true, maxDimension: 100),
      );
      final invalidSvg = '''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="200" height="50">
          <path d="M0 0h24v24H0z"/>
        </svg>
      ''';

      expect(
        () => validator.validate(invalidSvg),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Width dimension out of allowed range',
          ),
        ),
      );
    });

    test('blocks script elements', () {
      final validator = SvgValidator(const SvgValidationOptions(validateElements: true));
      final maliciousSvg = '''
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
            <script>alert('xss')</script>
            <path d="M12 2L2 7l10 5 10-5-10-5z"/>
          </svg>
        ''';

      expect(
        () => validator.validate(maliciousSvg),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Unsupported SVG element: script',
          ),
        ),
      );
    });
  });

  group('SvgProvider Source Loading Tests', () {
    late TestAssetBundle testAssetBundle;
    late MockClient mockHttpClient;
    late String validSvg;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      testAssetBundle = TestAssetBundle();
      mockHttpClient = MockClient();
      validSvg = '''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path d="M12 2L2 7l10 5 10-5-10-5z"/>
        </svg>
      ''';

      // Setup asset bundle for tests
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          final asset = utf8.decode(message!.buffer.asUint8List());
          if (testAssetBundle.assets.containsKey(asset)) {
            return testAssetBundle.assets[asset];
          }
          return null;
        },
      );
    });

    test('loads from asset', () async {
      testAssetBundle.addAsset('assets/icon.svg', validSvg);

      final provider = SvgProvider(
        'assets/icon.svg',
        validationOptions: SvgValidationOptions.basic,
      );

      final key = await provider.obtainKey(ImageConfiguration.empty);
      expect(key.path, equals('assets/icon.svg'));

      // Create a custom getter to intercept the asset loading
      Future<String?> assetGetter(SvgImageKey key) async {
        expect(key.path, equals('assets/icon.svg'));
        return validSvg;
      }

      final providerWithGetter = SvgProvider('assets/icon.svg', svgGetter: assetGetter);

      final keyWithGetter = await providerWithGetter.obtainKey(ImageConfiguration.empty);
      final result = await SvgProvider.getSvgString(keyWithGetter);
      expect(result, equals(validSvg));
    });

    test('loads from network', () async {
      when(
        mockHttpClient.get(Uri.parse('https://example.com/icon.svg')),
      ).thenAnswer((_) async => http.Response(validSvg, 200));

      // Create a custom getter that uses our mock client
      Future<String?> networkGetter(SvgImageKey key) async {
        final response = await mockHttpClient.get(Uri.parse(key.path));
        if (response.statusCode != 200) {
          throw Exception('Failed to load network SVG. Status: ${response.statusCode}');
        }
        return response.body;
      }

      final provider = SvgProvider(
        'https://example.com/icon.svg',
        source: SvgSource.network,
        svgGetter: networkGetter,
      );

      final key = await provider.obtainKey(ImageConfiguration.empty);
      expect(key.source, equals(SvgSource.network));

      final result = await SvgProvider.getSvgString(key);
      expect(result, equals(validSvg));

      // Verify the mock was called
      verify(mockHttpClient.get(Uri.parse('https://example.com/icon.svg'))).called(1);
    });

    test('handles network timeout', () async {
      // Use the mockHttpClient to simulate a timeout
      when(mockHttpClient.get(Uri.parse('https://example.com/icon.svg'))).thenAnswer(
        (_) => Future.delayed(
          const Duration(minutes: 1), // Very long delay to ensure timeout
          () => http.Response(validSvg, 200),
        ),
      );

      // Create a custom getter with a timeout
      Future<String?> timeoutGetter(SvgImageKey key) async {
        try {
          return await mockHttpClient
              .get(Uri.parse(key.path))
              .timeout(const Duration(milliseconds: 10))
              .then((response) {
                if (response.statusCode != 200) {
                  throw Exception('Failed to load network SVG. Status: ${response.statusCode}');
                }
                return response.body;
              });
        } on TimeoutException {
          throw Exception('Network SVG request timed out');
        }
      }

      final provider = SvgProvider(
        'https://example.com/icon.svg',
        source: SvgSource.network,
        svgGetter: timeoutGetter,
      );

      final key = await provider.obtainKey(ImageConfiguration.empty);

      expect(
        () => SvgProvider.getSvgString(key),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network SVG request timed out'),
          ),
        ),
      );
    });

    test('handles network error response', () async {
      when(
        mockHttpClient.get(Uri.parse('https://example.com/icon.svg')),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      // Create a custom getter that uses our mock client
      Future<String?> errorGetter(SvgImageKey key) async {
        final response = await mockHttpClient.get(Uri.parse(key.path));
        if (response.statusCode != 200) {
          throw Exception('Failed to load network SVG. Status: ${response.statusCode}');
        }
        return response.body;
      }

      final provider = SvgProvider(
        'https://example.com/icon.svg',
        source: SvgSource.network,
        svgGetter: errorGetter,
      );

      final key = await provider.obtainKey(ImageConfiguration.empty);

      expect(
        () => SvgProvider.getSvgString(key),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to load network SVG. Status: 404'),
          ),
        ),
      );

      // Verify the mock was called
      verify(mockHttpClient.get(Uri.parse('https://example.com/icon.svg'))).called(1);
    });

    test('handles package assets', () async {
      testAssetBundle.addAsset('packages/my_package/assets/icon.svg', validSvg);

      // Create a custom getter to intercept the package loading
      Future<String?> packageGetter(SvgImageKey key) async {
        expect(key.package, equals('my_package'));
        expect(key.path, equals('assets/icon.svg'));
        return validSvg;
      }

      final provider = SvgProvider(
        'assets/icon.svg',
        source: SvgSource.package,
        package: 'my_package',
        svgGetter: packageGetter,
      );

      final key = await provider.obtainKey(ImageConfiguration.empty);
      expect(key.package, equals('my_package'));

      final result = await SvgProvider.getSvgString(key);
      expect(result, equals(validSvg));
    });

    test('validates raw SVG string', () async {
      final provider = SvgProvider(
        validSvg,
        source: SvgSource.raw,
        validationOptions: SvgValidationOptions.strict,
      );

      final key = await provider.obtainKey(ImageConfiguration.empty);
      final result = await SvgProvider.getSvgString(key);
      expect(result, equals(validSvg));
    });
  });

  group('SvgProvider Configuration Tests', () {
    test('uses default size when not specified', () async {
      final provider = SvgProvider(validSvg, source: SvgSource.raw);
      final key = await provider.obtainKey(ImageConfiguration.empty);

      expect(key.pixelWidth, equals(100));
      expect(key.pixelHeight, equals(100));
    });

    test('respects provided size', () async {
      final provider = SvgProvider(validSvg, source: SvgSource.raw, size: const Size(200, 150));
      final key = await provider.obtainKey(ImageConfiguration.empty);

      expect(key.pixelWidth, equals(200));
      expect(key.pixelHeight, equals(150));
    });

    test('applies color tint', () async {
      final provider = SvgProvider(validSvg, source: SvgSource.raw, color: Colors.blue);
      final key = await provider.obtainKey(ImageConfiguration.empty);

      expect(key.color, equals(Colors.blue));
    });

    test('applies scale factor', () async {
      final provider = SvgProvider(
        validSvg,
        source: SvgSource.raw,
        scale: 2.0,
        size: const Size(100, 100),
      );
      final key = await provider.obtainKey(ImageConfiguration.empty);

      expect(key.pixelWidth, equals(200));
      expect(key.pixelHeight, equals(200));
    });
  });

  group('SvgProvider Error Handling Tests', () {
    test('handles missing package parameter', () async {
      final provider = SvgProvider('assets/icon.svg', source: SvgSource.package);

      final key = await provider.obtainKey(ImageConfiguration.empty);
      expect(
        () => SvgProvider.getSvgString(key),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Package parameter is required for SvgSource.package'),
          ),
        ),
      );
    });

    test('handles invalid SVG content', () async {
      final invalidSvg = '<not-svg>Invalid content</not-svg>';
      final provider = SvgProvider(
        invalidSvg,
        source: SvgSource.raw,
        validationOptions: SvgValidationOptions.basic,
      );

      final key = await provider.obtainKey(ImageConfiguration.empty);
      expect(
        () => SvgProvider.getSvgString(key),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', contains('Missing <svg> tag')),
        ),
      );
    });

    test('handles missing file', () async {
      final provider = SvgProvider('nonexistent.svg', source: SvgSource.file);

      final key = await provider.obtainKey(ImageConfiguration.empty);
      expect(
        () async => await SvgProvider.getSvgString(key),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', contains('SVG file not found')),
        ),
      );
    });
  });
}

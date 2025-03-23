import 'package:flutter/material.dart';
import 'package:svg_provider/svg_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SVG Provider Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Basic asset example
              Image(width: 100, height: 100, image: SvgProvider('assets/icon.svg')),

              const SizedBox(height: 20),

              // Network example with validation
              Image(
                width: 100,
                height: 100,
                image: SvgProvider(
                  'https://example.com/sample.svg',
                  source: SvgSource.network,
                  validationOptions: SvgValidationOptions.strict,
                ),
              ),

              const SizedBox(height: 20),

              // Raw SVG example with color
              Image(
                width: 100,
                height: 100,
                image: SvgProvider(
                  '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
                      <circle cx="50" cy="50" r="40" stroke="black" stroke-width="2" fill="currentColor" />
                    </svg>''',
                  source: SvgSource.raw,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

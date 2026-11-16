import 'package:flutter/material.dart';

class FeatureUnavailablePage extends StatelessWidget {
  const FeatureUnavailablePage({super.key, required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 40),
            const SizedBox(height: 16),
            Text(
              '$feature is not available right now.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('This feature is not part of the current Kaydo beta.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    ),
  );
}

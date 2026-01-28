
import 'dart:io';
import 'package:flutter/material.dart';

/// Placeholder purchase screen for iOS (never shown), and normal for Android
class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // On iOS, never show the purchase screen
    if (Platform.isIOS) {
      // Immediately pop if somehow navigated here
      Future.microtask(() => Navigator.of(context).maybePop());
      return const SizedBox.shrink();
    }
    // On Android, show a message that premium is unlocked or not available
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Premium')),
      body: const Center(
        child: Text(
          'Premium features are unlocked on iOS.\nNo purchase required.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

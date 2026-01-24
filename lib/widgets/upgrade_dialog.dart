import 'package:flutter/material.dart';
import '../screens/purchase_screen.dart';

/// Dialog to prompt users to upgrade to premium
class UpgradeToPremiumDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onUpgrade;

  const UpgradeToPremiumDialog({
    super.key,
    required this.title,
    required this.message,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.star, color: Colors.amber.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Features:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFeature('✓ Unlimited teams'),
                _buildFeature('✓ Unlimited games'),
                _buildFeature('✓ PDF reports & season summaries'),
                _buildFeature('✓ Advanced goalie analysis'),
                _buildFeature('✓ Shot heat maps & zone tracking'),
                _buildFeature('✓ Full season statistics'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not Now'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to purchase screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseScreen()),
            );
            if (onUpgrade != null) {
              onUpgrade!();
            }
          },
          icon: const Icon(Icons.star),
          label: const Text('Upgrade to Premium'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade600,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}

/// Show upgrade dialog helper
Future<void> showUpgradeDialog(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? onUpgrade,
}) {
  return showDialog(
    context: context,
    builder: (context) => UpgradeToPremiumDialog(
      title: title,
      message: message,
      onUpgrade: onUpgrade,
    ),
  );
}

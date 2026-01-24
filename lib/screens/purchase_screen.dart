import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../services/premium_service.dart';

/// Screen for purchasing premium features
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _loading = true;
  bool _purchasing = false;
  
  // TODO: Replace with your actual product ID from Google Play Console
  static const String _productId = 'premium_upgrade';

  @override
  void initState() {
    super.initState();
    _initializePurchase();
  }

  Future<void> _initializePurchase() async {
    // Check if in-app purchases are available
    final available = await _iap.isAvailable();
    setState(() {
      _isAvailable = available;
    });

    if (!available) {
      setState(() {
        _loading = false;
      });
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase error: $error')),
        );
      },
    );

    // Load products
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails({_productId});
    
    if (response.error != null) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: ${response.error!.message}')),
      );
      return;
    }

    setState(() {
      _products = response.productDetails;
      _loading = false;
    });
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        setState(() {
          _purchasing = true;
        });
      } else if (purchase.status == PurchaseStatus.error) {
        setState(() {
          _purchasing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: ${purchase.error}')),
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verify purchase on your server if needed
        await _verifyAndDeliverProduct(purchase);
        setState(() {
          _purchasing = false;
        });
      }

      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchase) async {
    // TODO: Verify purchase with your backend if needed
    
    // Grant premium access
    await PremiumService.setPremium(true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Welcome to Premium!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Return to previous screen
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _buyProduct(ProductDetails product) async {
    setState(() {
      _purchasing = true;
    });

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      setState(() {
        _purchasing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase error: $e')),
      );
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _purchasing = true;
    });

    try {
      await _iap.restorePurchases();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking previous purchases...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }

    setState(() {
      _purchasing = false;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isAvailable
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'In-app purchases are not available on this device.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 80,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Unlock Premium Features',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        _buildFeatureItem(
                          Icons.group,
                          'Unlimited Teams',
                          'Create and manage as many teams as you need',
                        ),
                        _buildFeatureItem(
                          Icons.sports_hockey,
                          'Unlimited Games',
                          'Track every game throughout the season',
                        ),
                        _buildFeatureItem(
                          Icons.picture_as_pdf,
                          'PDF Reports',
                          'Generate professional game and season reports',
                        ),
                        _buildFeatureItem(
                          Icons.analytics,
                          'Advanced Analysis',
                          'Access goalie zone analysis and shot tracking',
                        ),
                        _buildFeatureItem(
                          Icons.grid_on,
                          'Heat Maps',
                          'Visualize shot patterns and save percentages',
                        ),
                        _buildFeatureItem(
                          Icons.bar_chart,
                          'Full Statistics',
                          'Complete season tracking and player stats',
                        ),
                        const SizedBox(height: 30),
                        if (_products.isNotEmpty)
                          ..._products.map((product) {
                            return Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      product.title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(product.description),
                                    const SizedBox(height: 16),
                                    Text(
                                      product.price,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'One-time purchase',
                                      style: TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _purchasing
                                          ? null
                                          : () => _buyProduct(product),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade600,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 16,
                                        ),
                                      ),
                                      child: _purchasing
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Purchase Premium',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        if (_products.isEmpty && !_loading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No products available at this time. Please try again later.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _purchasing ? null : _restorePurchases,
                          child: const Text('Restore Previous Purchase'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Already purchased? Use "Restore Purchase" to regain access.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.amber.shade800,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

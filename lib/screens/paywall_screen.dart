import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../providers/providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _restoring = false;

  Future<void> _restorePurchase() async {
    setState(() => _restoring = true);
    final restored = await ref
        .read(purchaseServiceProvider)
        .restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    // If a purchase was restored, isPremiumProvider is already true by
    // now and this screen is about to be replaced -- the message would
    // just flash and disappear, so only show it for the "nothing found"
    // case, which otherwise has no feedback at all.
    if (!restored) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous purchase found to restore.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(purchaseServiceProvider);
    final price = service.productDetails?.price ?? r'$2.99';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You've used your $kFreePostLimit free posts!",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "You've reached the free limit. Unlock "
                            'unlimited posting to keep going.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () =>
                                  ref.read(purchaseServiceProvider).buyPremium(),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text('Unlock for $price'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _restoring ? null : _restorePurchase,
                              child: _restoring
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Restore purchase'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

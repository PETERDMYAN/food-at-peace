import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../data/iap_service.dart';
import '../../models/bean_transaction.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bean_icon.dart';

/// The Beans wallet: a gradient balance hero, a top-up action, and the full
/// transaction history (welcome bonus, photo scans, purchases, refunds).
class BeansScreen extends ConsumerWidget {
  const BeansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final beans = ref.watch(beansProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.beans)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _BalanceHero(beans: beans),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showBeansPaywall(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.beanAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: Text(t.topUp),
            ),
          ),
          const SizedBox(height: 24),
          Text(t.beansHistory, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (beans.ledger.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                t.beansEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final txn in beans.ledger) _TxnRow(txn: txn),
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.beans});

  final BeansState beans;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: AppTheme.beanGradient,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BeanIcon(size: 30),
              const SizedBox(width: 10),
              Text(
                t.beansBalance,
                style: text.titleMedium?.copyWith(
                  color: AppTheme.beanInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${beans.balance}',
            style: text.displaySmall?.copyWith(
              color: AppTheme.beanInk,
              fontWeight: FontWeight.w800,
              fontSize: 44,
            ),
          ),
          Text(
            t.beansPerScan,
            style: text.bodySmall?.copyWith(
              color: AppTheme.beanInk.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});

  final BeanTransaction txn;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final positive = txn.amount >= 0;
    final (icon, title) = switch (txn.type) {
      BeanTxnType.signupGrant => (Icons.celebration_outlined, t.beansGrant),
      BeanTxnType.spend => (Icons.photo_camera_outlined, t.beansSpend),
      BeanTxnType.purchase => (Icons.add_circle_outline, t.beansPurchase),
      BeanTxnType.refund => (Icons.undo, t.beansRefund),
    };
    final subtitle = [
      DateFormat('MMM d, HH:mm').format(txn.timestamp),
      if (txn.note != null && txn.note!.isNotEmpty) txn.note!,
      if (txn.priceSgd != null) t.priceSgd(txn.priceSgd!.toStringAsFixed(2)),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: scheme.onSurfaceVariant),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${positive ? '+' : '−'}${txn.amount.abs()}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: positive ? const Color(0xFF34B36A) : scheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            const BeanIcon(size: 18),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet paywall: buy a consumable Bean pack through StoreKit. The packs
/// map to the App Store Connect products (`beans_100…beans_800`); a completed
/// purchase credits the wallet ([IapService] → `BeansNotifier.recordPurchase`).
Future<void> showBeansPaywall(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _PaywallSheet(),
  );
}

class _PaywallSheet extends ConsumerWidget {
  const _PaywallSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    // StoreKit's localized price strings, keyed by product ID; empty before they
    // load (or on the simulator) — we fall back to the indicative SGD price.
    final prices = ref.watch(beanProductsProvider).asData?.value ?? const {};

    // Capture the messenger so the toast survives popping the sheet.
    final messenger = ScaffoldMessenger.of(context);
    void toast(String msg) =>
        messenger.showSnackBar(SnackBar(content: Text(msg)));

    Future<void> buyPack(int beans) async {
      final productId = beanProductId(beans);
      if (productId == null) return;
      final result = await ref.read(iapServiceProvider).buy(productId);
      if (!context.mounted) return;
      switch (result.outcome) {
        case IapOutcome.purchased:
          Navigator.pop(context);
          toast(t.beansBought(result.beans ?? beans));
        case IapOutcome.canceled:
          break;
        case IapOutcome.pending:
          toast(t.iapPending);
        case IapOutcome.unavailable:
          toast(t.iapUnavailable);
        case IapOutcome.error:
          toast(result.message ?? t.iapFailed);
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BeanIcon(size: 44)),
            const SizedBox(height: 12),
            Text(
              t.paywallTitle,
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              t.paywallBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(t.beansChoosePack, style: text.titleSmall),
            ),
            const SizedBox(height: 10),
            for (final p in BeanPricing.packs)
              _PackTile(
                label: t.beansCount(p.beans),
                trailing:
                    prices[beanProductId(p.beans)]?.price ??
                    t.priceSgd(p.sgd.toStringAsFixed(2)),
                badge: p.beans == 800 ? t.beansBestValue : null,
                onTap: () => buyPack(p.beans),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact top-up row: a Bean pack ("200 Beans" · "S$3.99") with an optional
/// "Best value" badge.
class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.label,
    required this.trailing,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String trailing;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const BeanIcon(size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.beanGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: text.labelSmall?.copyWith(
                            color: AppTheme.beanInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                trailing,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.beanAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

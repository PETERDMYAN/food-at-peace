import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../models/bean_transaction.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bean_icon.dart';

/// The Beans wallet: a gradient balance hero, top-up / go-unlimited actions,
/// and the full transaction history (welcome bonus, photo scans, purchases,
/// refunds).
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
          Row(
            children: [
              Expanded(
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
              if (!beans.subscribed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showBeansPaywall(context, ref),
                    icon: const Icon(Icons.all_inclusive),
                    label: Text(t.goUnlimited),
                  ),
                ),
              ],
            ],
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
            beans.subscribed ? t.beansUnlimited : '${beans.balance}',
            style: text.displaySmall?.copyWith(
              color: AppTheme.beanInk,
              fontWeight: FontWeight.w800,
              fontSize: 44,
            ),
          ),
          if (!beans.subscribed)
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

/// Bottom-sheet paywall shown when out of Beans (or from the wallet's top-up
/// buttons): buy a 100-Bean pack or go unlimited.
///
/// DEV STUB: the buttons credit locally and pop. Replace the
/// `purchasePack()` / `subscribeUnlimited()` calls with real StoreKit IAP +
/// receipt validation before shipping.
Future<void> showBeansPaywall(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PaywallSheet(parentRef: ref),
  );
}

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet({required this.parentRef});

  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final notifier = parentRef.read(beansProvider.notifier);

    // Capture the messenger so the toast survives popping the sheet.
    final messenger = ScaffoldMessenger.of(context);
    void toast(String msg) =>
        messenger.showSnackBar(SnackBar(content: Text(msg)));

    Future<void> buyPack(int beans, double sgd) async {
      await notifier.purchasePack(beans, sgd);
      if (context.mounted) Navigator.pop(context);
      toast(t.beansBought(beans));
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
                trailing: t.priceSgd(p.sgd.toStringAsFixed(2)),
                badge: p.beans == 800 ? t.beansBestValue : null,
                onTap: () => buyPack(p.beans, p.sgd),
              ),
            _PackTile(
              label: t.beansCustom,
              trailing: '',
              isCustom: true,
              onTap: () async {
                final amount = await showDialog<int>(
                  context: context,
                  builder: (_) => const _CustomTopUpDialog(),
                );
                if (amount != null && amount > 0) {
                  await buyPack(amount, BeanPricing.priceFor(amount));
                }
              },
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: t.beansUnlimited,
              price: t.priceSgdPerMonth(
                BeanPricing.subscriptionSgdPerMonth.toStringAsFixed(2),
              ),
              highlighted: true,
              onTap: () async {
                await notifier.subscribeUnlimited();
                if (context.mounted) Navigator.pop(context);
                toast(t.beansSubscribed);
              },
            ),
            const SizedBox(height: 14),
            Text(
              t.beansStubNote,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.highlighted,
    required this.onTap,
  });

  final String title;
  final String price;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          gradient: highlighted ? AppTheme.beanGradient : null,
          color: highlighted ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            BeanIcon(size: highlighted ? 30 : 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: highlighted ? AppTheme.beanInk : null,
                ),
              ),
            ),
            Text(
              price,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: highlighted ? AppTheme.beanInk : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact top-up row: a Bean pack ("200 Beans" · "SGD 3.99"), an optional
/// "Best value" badge, or the "Custom" entry (chevron, opens the amount dialog).
class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.label,
    required this.trailing,
    required this.onTap,
    this.badge,
    this.isCustom = false,
  });

  final String label;
  final String trailing;
  final VoidCallback onTap;
  final String? badge;
  final bool isCustom;

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
              if (isCustom)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
              else
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

/// Enter a custom number of Beans; previews the indicative price and returns
/// the amount (Apple IAP still needs this to resolve to a fixed product/tier).
class _CustomTopUpDialog extends StatefulWidget {
  const _CustomTopUpDialog();

  @override
  State<_CustomTopUpDialog> createState() => _CustomTopUpDialogState();
}

class _CustomTopUpDialogState extends State<_CustomTopUpDialog> {
  final _controller = TextEditingController(text: '150');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final amount = int.tryParse(_controller.text.trim()) ?? 0;
    return AlertDialog(
      title: Text(t.beansCustomTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t.beansCustomLabel),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const BeanIcon(size: 18),
              const SizedBox(width: 8),
              Text(
                amount > 0
                    ? t.priceSgd(BeanPricing.priceFor(amount).toStringAsFixed(2))
                    : '—',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: amount > 0 ? () => Navigator.pop(context, amount) : null,
          child: Text(t.topUp),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'model.dart';

/// Draft/preview preferences. Real authorization/cancellation is server-owned.
class RenewalPreferencesCard extends StatelessWidget {
  const RenewalPreferencesCard({super.key, required this.selection});
  final PurchaseSelection selection;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (c, _) => WCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WText('Renews monthly', WType.title),
          const Gap(10),
          DropdownButtonFormField<RenewalMethod>(
            initialValue: selection.renewalMethod,
            decoration: const InputDecoration(labelText: 'Renewal payment'),
            items: const [
              DropdownMenuItem(
                value: RenewalMethod.upiAutopay,
                child: Text('UPI AutoPay · Recommended'),
              ),
              DropdownMenuItem(
                value: RenewalMethod.debitMandate,
                child: Text('Debit-card mandate'),
              ),
              DropdownMenuItem(
                value: RenewalMethod.invoice,
                child: Text('Prepaid invoice'),
              ),
            ],
            onChanged: (v) =>
                selection.update(() => selection.renewalMethod = v!),
          ),
          const Gap(12),
          const WText(
            'Cancel renewal anytime. Your already-paid washes stay scheduled.',
            WType.bodyStrong,
          ),
          const Gap(8),
          WText(
            selection.renewalMethod == RenewalMethod.invoice
                ? 'An invoice is sent before each new cycle. Pay it before that cycle starts to keep service active.'
                : 'Authorize automatic monthly payments during checkout.',
            WType.caption,
          ),
        ],
      ),
    ),
  );
}

class RenewalManageCard extends StatelessWidget {
  const RenewalManageCard({
    super.key,
    required this.selection,
    this.nextCycleSelection,
    this.onChanged,
  });
  final PurchaseSelection selection;
  final PurchaseSelection? nextCycleSelection;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final renewal = nextCycleSelection ?? selection;
    return WCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WText(
            selection.autoRenew ? 'Renews monthly' : 'Subscription cancelled',
            WType.title,
          ),
          const Gap(8),
          WText(
            selection.autoRenew
                ? 'Next cycle: ${shortDate(selection.endExclusive)} · ${renewal.money} prepaid'
                : 'Your paid washes remain available until ${shortDate(selection.endExclusive.subtract(const Duration(days: 1)))}.',
            WType.body,
          ),
          const Gap(8),
          WText(
            selection.autoRenew
                ? renewal.renewalMethod == RenewalMethod.invoice
                      ? 'Invoice before renewal · Payment required'
                      : renewal.renewalAuthorityGranted
                      ? '${renewal.renewalMethod == RenewalMethod.upiAutopay ? 'UPI AutoPay' : 'Debit mandate'} · Demo authorization recorded'
                      : 'Payment authorization required for the next cycle'
                : 'Paid-cycle refund: ₹0 · No next renewal charge',
            WType.caption,
          ),
          const Gap(12),
          WButton(
            selection.autoRenew ? 'Cancel subscription' : 'Resume subscription',
            kind: ButtonKind.outline,
            onTap: () async {
              final stop = selection.autoRenew;
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(
                    stop ? 'Cancel subscription?' : 'Resume subscription?',
                  ),
                  content: Text(
                    stop
                        ? 'Your paid cycle stays scheduled until ${shortDate(selection.endExclusive.subtract(const Duration(days: 1)))}. Paid-cycle refund: ₹0. No new cycle will be charged after cancellation is confirmed.'
                        : 'A new payment authorization is required for AutoPay. No charge is made in this preview.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(stop ? 'Keep subscription' : 'Back'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(
                        stop ? 'Cancel subscription' : 'Resume subscription',
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                selection.update(() {
                  selection.autoRenew = !stop;
                  selection.renewalAuthorityGranted = false;
                });
                if (nextCycleSelection != null)
                  nextCycleSelection!.update(() {
                    nextCycleSelection!.autoRenew = !stop;
                    nextCycleSelection!.renewalAuthorityGranted = false;
                  });
                onChanged?.call();
              }
            },
          ),
          if (selection.autoRenew &&
              !renewal.renewalAuthorityGranted &&
              renewal.renewalMethod != RenewalMethod.invoice)
            WButton(
              'Set up demo AutoPay',
              kind: ButtonKind.text,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Demo mandate approval'),
                    content: Text(
                      'Simulate approving recurring payments of ${renewal.money} per cycle. No bank account is connected.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Not now'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Simulate approval'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  selection.update(
                    () => selection.renewalAuthorityGranted = true,
                  );
                  nextCycleSelection?.update(
                    () => nextCycleSelection!.renewalAuthorityGranted = true,
                  );
                  onChanged?.call();
                }
              },
            ),
        ],
      ),
    );
  }
}

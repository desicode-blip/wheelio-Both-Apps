import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';
import '../data/store.dart';
import 'common.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.shortfallPaise = 0});
  final int shortfallPaise;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late String amount =
      (widget.shortfallPaise > 0
              ? widget.shortfallPaise.clamp(100, 1000000) / 100
              : 100)
          .toStringAsFixed(2);
  String? requestId, message;
  bool busy = false;
  int? get paise {
    if (!RegExp(r'^\d{1,5}(\.\d{0,2})?$').hasMatch(amount.trim())) return null;
    final value = ((num.tryParse(amount) ?? 0) * 100).round();
    return value >= 100 && value <= 1000000 ? value : null;
  }

  Future<void> pay({String? request, int? savedAmount}) async {
    if (busy) return;
    final store = context.store, value = savedAmount ?? paise;
    if (!store.isLive || value == null) return;
    setState(() {
      busy = true;
      message = null;
      requestId = request ?? requestId ?? newId('wallet');
    });
    try {
      final result = await store.addWalletCredit(requestId!, value);
      if (!mounted) return;
      setState(
        () => message = result['status'] == 'credited'
            ? '${Fmt.rupees((result['amountPaise'] as int) / 100)} added to your wallet.'
            : result['status'] == 'refundPending'
            ? 'This payment cannot fund your wallet. A refund to the original method has been queued.'
            : 'Payment is not confirmed yet. Check the pending top-up before paying again.',
      );
      if (result['paymentStatus'] == 'captured') requestId = null;
    } catch (e) {
      if (mounted) setState(() => message = backendError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, balance = store.customer?.credit ?? 0;
    return PopScope(
      canPop: !busy,
      child: WScreen(
        header: const PlainHeader(),
        footer: WFooterBar(
          showCall: false,
          child: WButton(
            busy
                ? (store.checkoutStage == CheckoutStage.confirming
                      ? 'Confirming top-up…'
                      : 'Opening secure payment…')
                : 'Top up ${paise == null ? 'wallet' : Fmt.rupees(paise! / 100)}',
            kind: ButtonKind.success,
            enabled: !busy && paise != null && store.isLive,
            onTap: () => pay(),
          ),
        ),
        children: [
          const WTitleBlock(
            'Your wallet',
            subtitle: 'Credits for your next wash.',
          ),
          WCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WText('Available balance', WType.body),
                const SizedBox(height: 8),
                WText(Fmt.rupees(balance), WType.screen, color: WColor.primary),
                const SizedBox(height: 10),
                const WText(
                  '₹1 credit pays for ₹1 of a wash. Credits can be used only in ${Brand.name}; they cannot be withdrawn or transferred.',
                  WType.caption,
                ),
                const SizedBox(height: 8),
                const WText('Credits expire one year after being added. The oldest credits are used first.', WType.caption),
                for(final lot in store.walletCreditLots.where((l)=>(l['expiresAt'] as num)>DateTime.now().millisecondsSinceEpoch))
                  Padding(padding: const EdgeInsets.only(top: 6), child: WText('${Fmt.rupees((lot['amountPaise'] as num)/100)} expires ${Fmt.date(DateTime.fromMillisecondsSinceEpoch((lot['expiresAt'] as num).toInt()))} ${DateTime.fromMillisecondsSinceEpoch((lot['expiresAt'] as num).toInt()).year}', WType.caption)),
              ],
            ),
          ),
          if (widget.shortfallPaise > 0) ...[
            const SizedBox(height: 16),
            WBanner(
              tone: Tone.info,
              icon: WIcon.rupee,
              text:
                  'Add credit, then return to Check and pay to choose Pay by wallet.',
            ),
          ],
          const SizedBox(height: 24),
          WTextField(
            label: 'Top-up amount (₹)',
            value: amount,
            placeholder: '100',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              if (!busy) {
                setState(() {
                  amount = v;
                  requestId = null;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          const WText(
            'Pay securely through Razorpay. Credit is added only after the server confirms payment. Credit cards, EMI and pay-later are unavailable.',
            WType.caption,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            WBanner(tone: Tone.info, icon: WIcon.receipt, text: message!),
          ],
          if (store.isLive && store.live?.uid != null) ...[
            const SizedBox(height: 24),
            const WText('Recent top-ups', WType.section),
            const SizedBox(height: 12),
            StreamBuilder(
              stream: store.live!.db
                  .collection('walletTopups')
                  .where('customerId', isEqualTo: store.live!.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return WText(backendError(snapshot.error!), WType.body);
                }
                final docs = snapshot.data?.docs;
                if (docs == null) {
                  return const WText('Loading wallet payments…', WType.body);
                }
                if (docs.isEmpty) {
                  return const WText(
                    'Your top-ups will appear here.',
                    WType.body,
                  );
                }
                return Column(
                  children: [
                    for (final doc in docs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: WCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              WText(
                                Fmt.rupees(
                                  (doc.data()['amountPaise'] as num) / 100,
                                ),
                                WType.title,
                              ),
                              WText(
                                doc.data()['status'] == 'credited'
                                    ? 'Added to wallet'
                                    : doc.data()['status'] == 'refundPending'
                                    ? 'Refund ${doc.data()['refundStatus'] ?? 'queued'}'
                                    : 'Awaiting payment confirmation',
                                WType.caption,
                              ),
                              if (doc.data()['paymentStatus'] !=
                                  'captured') ...[
                                WButton(
                                  'Check payment',
                                  kind: ButtonKind.text,
                                  enabled: !busy,
                                  onTap: () async {
                                    setState(() => busy = true);
                                    try {
                                      await store.live!.call(
                                        'checkWalletTopup',
                                        {'topupId': doc.id},
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        setState(
                                          () => message = backendError(e),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => busy = false);
                                    }
                                  },
                                ),
                                if (doc
                                        .data()['paymentExpiresAt']
                                        ?.toDate()
                                        .isAfter(DateTime.now()) ==
                                    true)
                                  WButton(
                                    'Continue payment',
                                    kind: ButtonKind.text,
                                    enabled: !busy,
                                    onTap: () => pay(
                                      request:
                                          doc.data()['requestId'] as String,
                                      savedAmount:
                                          doc.data()['amountPaise'] as int,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

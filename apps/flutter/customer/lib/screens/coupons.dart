import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart' show backendError;
import '../data/store.dart';
import 'common.dart';

/// Refund coupons are issued by an authorised human against a paid booking.
/// The app can display/apply them; it cannot create or fund them.
class CouponsScreen extends StatefulWidget {
 const CouponsScreen({super.key});
 @override State<CouponsScreen> createState()=>_CouponsScreenState();
}
class _CouponsScreenState extends State<CouponsScreen>{
 int limit=50;
 String? message;
 bool applying=false;
 Future<void> useCoupon(String code)async{
  if(applying)return;
  final store=context.store,router=context.router;
  if(store.draft.type==null||store.draft.place==null||store.draft.slot==null){
   store.startNewBooking();store.draft.couponCode=code;router.replace(const [R(N.vehicleType)]);return;
  }
  setState(()=>applying=true);
  try{await store.applyCoupon(code);if(mounted)router.replace(const [R(N.review)]);}
  catch(e){if(mounted)setState(()=>message=backendError(e));}
  finally{if(mounted)setState(()=>applying=false);}
 }
 @override Widget build(BuildContext context){
  final store=context.store,router=context.router;
  return WScreen(header:const PlainHeader(),children:[
   const WTitleBlock('Your coupons',subtitle:'Refund coupons issued by our team for your account.'),
   const WText('Each coupon is private and single-use. Any unused value is lost when payment is confirmed. Apply it at Check and pay; Razorpay collects any shortfall. Coupons cannot be topped up, withdrawn or transferred.',WType.caption),
   const SizedBox(height:20),
   if(message!=null)...[WBanner(tone:Tone.error,icon:WIcon.info,text:message!),const SizedBox(height:16)],
   if(!store.isLoggedIn)WButton('Log in to view coupons',onTap:()=>router.go(N.login))
   else if(store.live==null)const WBanner(tone:Tone.info,icon:WIcon.gift,text:'Issued refund coupons will appear here.')
   else StreamBuilder(
    stream:store.live!.db.collection('coupons').where('customerId',isEqualTo:store.live!.uid).where('paymentMode',isEqualTo:store.testPayments?'test':'live').orderBy('issuedAt',descending:true).limit(limit).snapshots(includeMetadataChanges:true),
    builder:(context,snapshot){
     if(snapshot.hasError)return const WBanner(tone:Tone.error,icon:WIcon.info,text:'Coupons could not load. Check your connection and reopen this page.');
     final docs=snapshot.data?.docs;
     if(docs==null)return const WText('Loading your coupons…',WType.body);
     if(docs.isEmpty)return const WBanner(tone:Tone.info,icon:WIcon.gift,text:'No coupons issued yet. Approved refund coupons will appear here.');
     return Column(children:[
      for(final doc in docs)...[
       Builder(builder:(context){
        final c=doc.data(),expires=c['expiresAt']?.toDate() as DateTime?,available=(c['availablePaise'] as num? ?? 0).toInt();
        final expired=expires==null||!expires.isAfter(DateTime.now()),usable=c['status']=='active'&&!expired&&available>0;
        return WCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Row(children:[const WIconBox(WIcon.gift),const SizedBox(width:12),Expanded(child:WText(Fmt.rupees(expired?0:available/100),WType.screen,color:WColor.primary))]),
         const SizedBox(height:14),WText(c['code'] as String? ?? '',WType.bodyStrong,mono:true),
         const SizedBox(height:6),WText(expired?'Expired':available>0?'Available for your next wash':(c['reservedPaise'] as num? ?? 0)>0?'Applied to a pending booking':'Used',WType.caption),
         if(expires!=null)WText('Valid until ${Fmt.date(expires)} ${expires.year}',WType.caption),
         if(usable)...[const SizedBox(height:14),WButton('Use coupon',kind:ButtonKind.success,loading:applying,enabled:!applying,onTap:()=>useCoupon(c['code'] as String)),
          WButton('Copy code',kind:ButtonKind.text,onTap:()async{await Clipboard.setData(ClipboardData(text:c['code'] as String));if(mounted)store.set(()=>store.toast='Coupon code copied.');})],
        ]));
       }),const SizedBox(height:14),
      ],
      if(docs.length==limit)WButton('Load more coupons',kind:ButtonKind.outline,onTap:()=>setState(()=>limit+=50)),
     ]);
    }),
   // v2 (12 Nov, Aman): after the coupons, a small way to earn more by referring.
   if(store.v2Features)...[
    const SizedBox(height:24),
    WCard(radius:16,outlined:true,onTap:()=>router.go(N.referrals),child:const Row(children:[
     WIconBox(WIcon.gift,size:40,tone:Tone.ok),SizedBox(width:12),
     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[WText('Want more?',WType.title),WText('Refer friends · free Premium washes',WType.caption)])),
     WIconView(WIcon.chevron,size:13,color:WColor.secondary),
    ])),
   ],
  ]);
 }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';
import '../data/store.dart';
import 'parts.dart';
import 'help.dart' show WorkSlotsEditor;

/// Owner-authorized coverage editor. The saved centre is independent of job GPS.
class ServiceAreaScreen extends StatefulWidget {
  const ServiceAreaScreen({super.key,this.setup=false});
  final bool setup;
  @override State<ServiceAreaScreen> createState()=>_ServiceAreaScreenState();
}
class _ServiceAreaScreenState extends State<ServiceAreaScreen>{
  double? latitude,longitude;
  int radius=3,generation=0;
  String label='',query='',token=List.generate(32,(_)=>'abcdefghijklmnopqrstuvwxyz0123456789'[Random.secure().nextInt(36)]).join();
  bool loaded=false,locating=false,searching=false,saving=false;
  String? error;
  Timer? debounce;
  List<Map<String,dynamic>> suggestions=[];
  List<WorkSlot> slots=[];
  @override void didChangeDependencies(){
    super.didChangeDependencies();if(loaded)return;loaded=true;
    final store=context.store,a=store.liveCaptain['serviceArea'];
    if(a is Map){latitude=(a['center']?['latitude'] as num?)?.toDouble();longitude=(a['center']?['longitude'] as num?)?.toDouble();radius=(a['radiusKm'] as num?)?.toInt()??3;label=a['label'] as String? ?? '';}
    slots=store.workSlots.isNotEmpty?[...store.workSlots]:[store.hasServiceArea?(workDayStart,workDayEnd):(9*60,18*60)];
  }
  @override void dispose(){generation++;debounce?.cancel();super.dispose();}
  Future<void> locate()async{
    if(locating)return;final store=context.store;
    setState((){locating=true;error=null;});
    try{final p=await store.live!.currentPosition();if(mounted)setState((){latitude=p.latitude;longitude=p.longitude;if(label.isEmpty)label='My work area';});}
    catch(e){if(mounted)setState(()=>error=backendError(e));}
    finally{if(mounted)setState(()=>locating=false);}
  }
  void search(String value){
    final g=++generation;debounce?.cancel();setState((){query=value;error=null;suggestions=[];searching=value.trim().length>=2;});
    if(value.trim().length<2)return;
    debounce=Timer(const Duration(milliseconds:350),()async{
      try{final r=await context.store.live!.call('searchPlaceSuggestions',{'query':value.trim(),'sessionToken':token,if(latitude!=null)'origin':{'latitude':latitude,'longitude':longitude}});if(mounted&&g==generation)setState(()=>suggestions=[for(final p in r['suggestions'] as List)Map<String,dynamic>.from(p as Map)]);}
      catch(e){if(mounted&&g==generation)setState(()=>error=backendError(e));}
      finally{if(mounted&&g==generation)setState(()=>searching=false);}
    });
  }
  Future<void> select(Map<String,dynamic> p)async{
    final g=++generation;debounce?.cancel();setState((){searching=true;error=null;});
    try{final r=await context.store.live!.call('selectPlaceSuggestion',{'placeId':p['placeId'],'sessionToken':token});if(!mounted||g!=generation)return;final place=r['place'] as Map;setState((){latitude=(place['latitude'] as num).toDouble();longitude=(place['longitude'] as num).toDouble();label=place['name'] as String;query=label;suggestions=[];});}
    catch(e){if(mounted&&g==generation)setState(()=>error=backendError(e));}
    finally{if(mounted&&g==generation)setState(()=>searching=false);}
  }
  Future<void> save()async{
    if(saving||latitude==null)return;final store=context.store,router=context.router;
    setState((){saving=true;error=null;});
    try{
      final result=await store.live!.call('saveCaptainServiceArea',{'center':{'latitude':latitude,'longitude':longitude},'radiusKm':radius,'label':label,'workingSlots':[for(final s in mergeSlots(slots)){'startMinute':s.$1,'endMinute':s.$2}]});
      if(!mounted)return;
      store.set((){store.liveCaptain['serviceArea']=result['serviceArea'];store.workSlots=mergeSlots(slots);store.refreshKycSteps();store.toast='Serving area saved';});
      if(widget.setup){router.replace(const [R(N.steps)]);}else{router.pop();}
    }catch(e){if(mounted)setState(()=>error=backendError(e));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context){
    final store=context.store;
    return WScreen(canvas:true,gutter:WSpace.gutterCaptain,
      header:const WHeader(title:'Serving area',help:false),
      footer:WFooter(child:WButton(saving?'Saving…':widget.setup?'Save and continue':'Save serving area',size:ButtonSize.captain,enabled:!saving&&!searching&&latitude!=null&&label.trim().length>=2,onTap:save)),
      children:[
        const WTitle('Where would you like to work?',top:10),
        const WBody('Choose a centre and how far you can travel. Every home and society inside your circle can book you during your working hours, after admin approval.',top:6,bottom:18),
        WTextField(label:'Search area or building',value:query,placeholder:'Type an area, society or landmark',onChanged:search),
        if(searching)const Padding(padding:EdgeInsets.all(16),child:Center(child:CircularProgressIndicator())),
        for(final p in suggestions)WListRow(icon:WIcon.location,title:p['name'] as String,subtitle:p['address'] as String? ?? '',onTap:()=>select(p)),
        if(suggestions.isNotEmpty)const Padding(padding:EdgeInsets.only(bottom:12),child:WText('Google Maps',WType.caption)),
        const SizedBox(height:12),
        if(latitude==null)WCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const WText('Why we ask for location',WType.title),
          const SizedBox(height:8),
          const WText('GPS helps you choose your work area. Your exact centre is private. It stays fixed until you change it here; travelling with your phone will not move your serving area.',WType.body),
          const SizedBox(height:12),
          WLink(locating?'Finding your location…':'Use current location',onTap:locate),
        ])) else ...[
          ClipRRect(borderRadius:BorderRadius.circular(20),child:SizedBox(height:300,child:LivePlaceMap(config:Map<String,dynamic>.from(store.liveConfig['maps'] as Map? ?? {}),latitude:latitude!,longitude:longitude!,radiusKm:radius.toDouble(),onMoved:(a,b)=>setState((){latitude=a;longitude=b;}),onLocate:()async{await locate();return latitude==null?null:(latitude!,longitude!);}))),
          const SizedBox(height:12),
          WCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[const Expanded(child:WText('Travel radius',WType.title)),WText('$radius km',WType.title,color:WColor.primary)]),
            Slider(value:radius.toDouble(),min:1,max:10,divisions:9,label:'$radius km',activeColor:WColor.primary,onChanged:saving?null:(v)=>setState(()=>radius=v.round())),
            const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[WText('1 km',WType.caption),WText('10 km',WType.caption)]),
            const SizedBox(height:8),WText(label,WType.rowTitle),
            const WText('Drag the map to move the centre. Changes take effect after you save.',WType.caption),
          ])),
        ],
        const WTitle('When do you work?',top:24),
        const WBody('Set the hours when customers can book you.',top:4,bottom:12),
        WorkSlotsEditor(slots:slots,onChanged:(v)=>setState(()=>slots=v)),
        if(error!=null)Padding(padding:const EdgeInsets.only(top:16),child:WText(error!,WType.body,color:WColor.destructive)),
        const SizedBox(height:24),
      ]);
  }
}

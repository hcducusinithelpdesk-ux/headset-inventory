import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const navy = Color(0xFF092B61);
const blue = Color(0xFF1265D8);
const bg = Color(0xFFF4F7FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HeadsetApp());
}

class HeadsetApp extends StatelessWidget {
  const HeadsetApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Headset Inventory',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
      fontFamily: 'Arial',
      cardTheme: CardThemeData(color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5EBF5)))),
    ),
    home: const LoginGate(),
  );
}

class Headset {
  final String id, tag, brand, model, serial, status, assignedTo, department, notes;
  final DateTime createdAt;
  Headset({required this.id, required this.tag, required this.brand, required this.model,
    required this.serial, required this.status, required this.assignedTo,
    required this.department, required this.notes, required this.createdAt});
  factory Headset.fromMap(Map<String,dynamic> m) => Headset(
    id: '${m['id']}', tag: '${m['asset_tag'] ?? ''}', brand: '${m['brand'] ?? ''}',
    model: '${m['model'] ?? ''}', serial: '${m['serial_number'] ?? ''}',
    status: '${m['status'] ?? 'Available'}', assignedTo: '${m['assigned_to'] ?? ''}',
    department: '${m['department'] ?? ''}', notes: '${m['notes'] ?? ''}',
    createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now());
  Map<String,dynamic> toMap() => {'asset_tag':tag,'brand':brand,'model':model,
    'serial_number':serial,'status':status,'assigned_to':assignedTo,
    'department':department,'notes':notes,'created_at':createdAt.toIso8601String()};
}

class InventoryStore extends ChangeNotifier {
  final List<Headset> items = [];
  static const _cacheKey='headset_inventory_cache_v1';
  final http.Client _client=http.Client();
  Timer? _refreshTimer;
  bool _online=false;
  bool get online => _online;
  Uri get _endpoint=>Uri.base.resolve('/api/headsets');

  Future<void> load() async {
    final prefs=await SharedPreferences.getInstance();
    final cached=prefs.getString(_cacheKey);
    if(cached!=null){
      try{
        final rows=(jsonDecode(cached) as List).cast<Map<String,dynamic>>();
        items..clear()..addAll(rows.map(Headset.fromMap));
        notifyListeners();
      }catch(_){}
    }
    await refreshFromCloud();
    _refreshTimer?.cancel();
    _refreshTimer=Timer.periodic(const Duration(seconds:4),(_)=>refreshFromCloud());
  }

  Future<void> _cacheItems() async{
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey,jsonEncode(items.map((h)=>{'id':h.id,...h.toMap()}).toList()));
  }

  Future<void> refreshFromCloud() async {
    try {
      final response=await _client.get(_endpoint).timeout(const Duration(seconds:5));
      if(response.statusCode!=200)throw Exception('Inventory API returned ${response.statusCode}');
      final decoded=jsonDecode(response.body) as List;
      final rows=decoded.map((row)=>Headset.fromMap(Map<String,dynamic>.from(row as Map))).toList();
      final before=jsonEncode(items.map((h)=>{'id':h.id,...h.toMap()}).toList());
      final after=jsonEncode(rows.map((h)=>{'id':h.id,...h.toMap()}).toList());
      final connectionChanged=!_online;
      _online=true;
      if(before!=after){
        items..clear()..addAll(rows);
        await _cacheItems();
        notifyListeners();
      }else if(connectionChanged){notifyListeners();}
    } catch (_) { _online=false; }
  }

  Future<void> _writeRemote(String method,Map<String,dynamic> body) async{
    final response=await _client.send(http.Request(method,_endpoint)
      ..headers['content-type']='application/json'
      ..body=jsonEncode(body)).timeout(const Duration(seconds:10));
    if(response.statusCode<200||response.statusCode>=300){
      throw Exception('Inventory API returned ${response.statusCode}: ${await response.stream.bytesToString()}');
    }
    _online=true;
  }

  Future<void> add(Headset h) async {
    try{await _writeRemote('POST',{'id':h.id,...h.toMap()});}catch(_){_online=false;}
    items.insert(0,h);
    await _cacheItems();
    notifyListeners();
  }
  Future<void> update(Headset h) async {
    try{await _writeRemote('PUT',{'id':h.id,...h.toMap()});}catch(_){_online=false;}
    final i=items.indexWhere((x)=>x.id==h.id); if(i>=0) items[i]=h;
    await _cacheItems();
    notifyListeners();
  }
  Future<void> delete(Headset h) async {
    try{await _writeRemote('DELETE',{'id':h.id});}catch(_){_online=false;}
    items.removeWhere((x)=>x.id==h.id); notifyListeners();
    await _cacheItems();
  }
  @override void dispose(){
    _refreshTimer?.cancel();
    _client.close();
    super.dispose();
  }
}

class InventoryShell extends StatefulWidget {
  final String username; final bool isAdmin;
  const InventoryShell({super.key, required this.username, required this.isAdmin});
  @override State<InventoryShell> createState()=>_InventoryShellState();
}

class CompanyLogo extends StatelessWidget {
  final double height;
  final bool showWordmark;
  const CompanyLogo({super.key, this.height=44, this.showWordmark=true});
  @override Widget build(BuildContext context) => Row(mainAxisSize:MainAxisSize.min,children:[
    CustomPaint(size:Size(height*1.3,height),painter:_CompanyMarkPainter()),
    if(showWordmark) ...[
      SizedBox(width:height*.18),
      Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('H.C.Ducusin',style:TextStyle(fontFamily:'serif',fontSize:height*.39,color:blue,height:1,fontWeight:FontWeight.w600)),
        SizedBox(height:height*.06),
        Text('INCORPORATED',style:TextStyle(fontFamily:'serif',fontSize:height*.13,color:blue,letterSpacing:height*.045,height:1)),
      ])
    ]
  ]);
}

class _CompanyMarkPainter extends CustomPainter {
  @override void paint(Canvas canvas,Size size) {
    final bluePaint=Paint()..color=blue;
    final navyPaint=Paint()..color=navy;
    final whitePaint=Paint()..color=Colors.white;
    canvas.drawOval(Rect.fromLTWH(size.width*.08,size.height*.01,size.width*.90,size.height*.98),navyPaint);
    canvas.drawOval(Rect.fromLTWH(size.width*.01,size.height*.10,size.width*.90,size.height*.88),bluePaint);
    canvas.drawOval(Rect.fromLTWH(size.width*.20,size.height*.29,size.width*.59,size.height*.54),navyPaint);
    canvas.drawOval(Rect.fromLTWH(size.width*.25,size.height*.28,size.width*.51,size.height*.46),whitePaint);
    canvas.drawRect(Rect.fromLTWH(size.width*.45,size.height*.13,size.width*.18,size.height*.74),bluePaint);
  }
  @override bool shouldRepaint(covariant _CompanyMarkPainter oldDelegate)=>false;
}

class _InventoryShellState extends State<InventoryShell> {
  final store=InventoryStore();
  int page=0;
  @override void initState(){super.initState();store.load();}
  @override void dispose(){store.dispose();super.dispose();}
  Future<void> _logout() async{
    final prefs=await SharedPreferences.getInstance();
    await prefs.remove('session_username');
    if(!mounted)return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder:(_)=>const LoginGate()),
      (route)=>false,
    );
  }
  @override Widget build(BuildContext context) {
    final wide=MediaQuery.sizeOf(context).width>800;
    final pages=[DashboardPage(store:store),
      InventoryPage(store:store,readOnly:!widget.isAdmin), AssignmentsPage(store:store), ReportsPage(store:store), const SettingsPage(),
      if(widget.isAdmin) UsersPage()];
    return Scaffold(body:Row(children:[
      if(wide) _Sidebar(page:page,onSelect:(v)=>setState(()=>page=v),isAdmin:widget.isAdmin),
      Expanded(child:Column(children:[
        AnimatedBuilder(animation:store,builder:(context,_)=>_Topbar(online:store.online,username:widget.username,onLogout:_logout,onMenu:wide?null:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Use the bottom navigation to switch pages.'))))),
        Expanded(child:pages[page]),
        if(!wide) NavigationBar(selectedIndex:page,onDestinationSelected:(v)=>setState(()=>page=v),
          destinations:[
            const NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Home'),
            const NavigationDestination(icon:Icon(Icons.headphones),label:'Stock'),
            const NavigationDestination(icon:Icon(Icons.assignment_ind_outlined),label:'Assign'),
            const NavigationDestination(icon:Icon(Icons.bar_chart),label:'Reports'),
            const NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Settings'),
            if(widget.isAdmin) const NavigationDestination(icon:Icon(Icons.people_alt_outlined),label:'Users')
          ])
      ]))
    ]));
  }
}

class _Sidebar extends StatelessWidget {
 final int page; final ValueChanged<int> onSelect; final bool isAdmin;
 const _Sidebar({required this.page,required this.onSelect,required this.isAdmin});
 @override Widget build(BuildContext context)=>Container(width:238,color:navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const SizedBox(height:28),Center(child:Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(8)),child:const CompanyLogo(height:38))),
  const SizedBox(height:12),const Center(child:Text('HEADSET INVENTORY',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.bold,letterSpacing:1))),
  const SizedBox(height:6),const Center(child:Text('Manage • Track • Monitor',style:TextStyle(color:Colors.white70,fontSize:11))),
  const SizedBox(height:32),
  ...[
    ('Dashboard',Icons.dashboard_outlined),('Inventory',Icons.inventory_2_outlined),
    ('Assignments',Icons.assignment_ind_outlined),('Reports',Icons.bar_chart_rounded),
    ('Settings',Icons.settings_outlined), if(isAdmin) ('User Management',Icons.people_alt_outlined)
  ].asMap().entries.map((e){
    final selected=page==e.key;
    return Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:InkWell(
      borderRadius:BorderRadius.circular(12),onTap:()=>onSelect(e.key),
      child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:14),decoration:BoxDecoration(color:selected?blue:Colors.transparent,borderRadius:BorderRadius.circular(12)),
        child:Row(children:[Icon(e.value.$2,color:Colors.white,size:21),const SizedBox(width:14),Text(e.value.$1,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600))]))));
  }),
  const Spacer(),const Padding(padding:EdgeInsets.all(18),child:Row(children:[Icon(Icons.circle,color:Color(0xFF20D69A),size:12),SizedBox(width:8),Text('System Ready',style:TextStyle(color:Colors.white70,fontSize:12))])),const SizedBox(height:10)
 ]));
}

class _Topbar extends StatelessWidget {
 final bool online; final String username; final VoidCallback onLogout; final VoidCallback? onMenu;
 const _Topbar({required this.online,required this.username,required this.onLogout,this.onMenu});
 @override Widget build(BuildContext context)=>Container(height:68,color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:24),child:Row(children:[
  if(onMenu!=null) IconButton(onPressed:onMenu,icon:const Icon(Icons.menu)),
  const CompanyLogo(height:30,showWordmark:false),const SizedBox(width:8),const Text('Headset Inventory',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:navy)),
  const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:online?const Color(0xFFE4F8F1):const Color(0xFFFFF4DF),borderRadius:BorderRadius.circular(20)),
    child:Row(children:[Icon(online?Icons.cloud_done:Icons.cloud_off,color:online?Colors.green:Colors.orange,size:17),const SizedBox(width:6),Text(online?'Cloud Connected':'Demo Mode',style:TextStyle(color:online?Colors.green.shade800:Colors.orange.shade900,fontSize:12,fontWeight:FontWeight.bold))])),
  const SizedBox(width:16),const CircleAvatar(backgroundColor:Color(0xFFEAF1FC),child:Icon(Icons.person,color:navy)),const SizedBox(width:8),Text(username,style:const TextStyle(fontWeight:FontWeight.w600)),
  IconButton(tooltip:'Log out',onPressed:onLogout,icon:const Icon(Icons.logout,color:navy))
 ]));
}

class DashboardPage extends StatelessWidget {
 final InventoryStore store;
 const DashboardPage({super.key,required this.store});
 @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
  final total=store.items.length,available=store.items.where((x)=>x.status=='Available').length,issued=store.items.where((x)=>x.status=='Issued').length,defective=store.items.where((x)=>x.status=='Defective').length;
  final now=DateTime.now();
  final months=List.generate(6,(i)=>DateTime(now.year,now.month-5+i));
  final monthlyAssets=months.map((month)=>store.items.where((item)=>item.createdAt.year==month.year&&item.createdAt.month==month.month).toList()).toList();
  final maxMonthlyCount=monthlyAssets.map((assets)=>assets.length).fold<int>(0,(max,count)=>count>max?count:max);
  return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Dashboard',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold,color:navy)),SizedBox(height:4),Text('Monitor and manage your headset assets',style:TextStyle(color:Colors.blueGrey))])),const CompanyLogo(height:38)]),
   const SizedBox(height:22),Wrap(spacing:14,runSpacing:14,children:[
    _StatCard(title:'Total Headsets',value:'$total',icon:Icons.headphones,color:blue),
    _StatCard(title:'Available',value:'$available',icon:Icons.check_circle,color:const Color(0xFF10A779)),
    _StatCard(title:'Issued',value:'$issued',icon:Icons.people_alt,color:const Color(0xFFF28B24)),
    _StatCard(title:'Defective',value:'$defective',icon:Icons.warning_rounded,color:const Color(0xFFE3485B)),
   ]),
   const SizedBox(height:20),LayoutBuilder(builder:(context,c)=>Wrap(spacing:16,runSpacing:16,children:[
    SizedBox(width:c.maxWidth>950?c.maxWidth*.57:c.maxWidth,child:_Panel(title:'Inventory Overview',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[_Legend(color:blue,label:'Total'),_Legend(color:Color(0xFF10A779),label:'Available'),_Legend(color:Color(0xFFF28B24),label:'Issued'),_Legend(color:Color(0xFFE3485B),label:'Defective')]),
      const SizedBox(height:12),_MonthlyInventoryChart(months:months,monthlyAssets:monthlyAssets,maxCount:maxMonthlyCount)
    ]))),
    SizedBox(width:c.maxWidth>950?c.maxWidth*.39:c.maxWidth,child:_Panel(title:'Headset Status',child:Column(children:[
      _StatusBar(label:'Available',count:available,total:total,color:const Color(0xFF10A779)),
      _StatusBar(label:'Issued',count:issued,total:total,color:blue),
      _StatusBar(label:'Defective',count:defective,total:total,color:const Color(0xFFE3485B)),
      const SizedBox(height:12),Text('$total total assets',style:const TextStyle(fontSize:12,color:Colors.blueGrey))
    ])))
   ])),

  ]));
 });
}

class _MonthlyInventoryChart extends StatelessWidget {
  final List<DateTime> months;
  final List<List<Headset>> monthlyAssets;
  final int maxCount;
  const _MonthlyInventoryChart({required this.months,required this.monthlyAssets,required this.maxCount});

  @override Widget build(BuildContext context){
    const colors=[blue,Color(0xFF10A779),Color(0xFFF28B24),Color(0xFFE3485B)];
    return SizedBox(height:160,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:List.generate(months.length,(i){
      final assets=monthlyAssets[i];
      final counts=[assets.length,assets.where((x)=>x.status=='Available').length,assets.where((x)=>x.status=='Issued').length,assets.where((x)=>x.status=='Defective').length];
      return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
        Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:List.generate(counts.length,(j){
          final height=maxCount==0||counts[j]==0?3.0:(counts[j]/maxCount*92).clamp(3.0,92.0).toDouble();
          return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:1),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
            Text('${counts[j]}',style:const TextStyle(fontSize:8,color:Colors.blueGrey)),
            const SizedBox(height:2),
            Container(height:height,decoration:BoxDecoration(color:colors[j].withOpacity(.9),borderRadius:BorderRadius.circular(3))),
          ])));
        }))),
        const SizedBox(height:7),
        Text(DateFormat('MMM').format(months[i]),style:const TextStyle(fontSize:11,color:Colors.blueGrey)),
      ])));
    })));
  }
}

class _StatCard extends StatelessWidget {
 final String title,value;final IconData icon;final Color color;
 const _StatCard({required this.title,required this.value,required this.icon,required this.color});
 @override Widget build(BuildContext context)=>SizedBox(width:MediaQuery.sizeOf(context).width>800?((MediaQuery.sizeOf(context).width-300-90)/4).clamp(170,300):MediaQuery.sizeOf(context).width*.42,
 child:Card(child:Padding(padding:const EdgeInsets.all(17),child:Row(children:[
  Container(width:48,height:48,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:color,size:26)),
  const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.blueGrey,fontSize:12)),const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold,color:navy))]))
 ]))));
}
class _Panel extends StatelessWidget {
 final String title;final Widget child;final Widget? action;
 const _Panel({required this.title,required this.child,this.action});
 @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[Expanded(child:Text(title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:navy))),if(action!=null)action!]),const Divider(height:24),child
 ])));
}
class _Legend extends StatelessWidget {final Color color;final String label;const _Legend({required this.color,required this.label});@override Widget build(BuildContext context)=>Expanded(child:Row(children:[Container(width:9,height:9,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:5),Flexible(child:Text(label,style:const TextStyle(fontSize:10)))]));}
class _StatusBar extends StatelessWidget {final String label;final int count,total;final Color color;const _StatusBar({required this.label,required this.count,required this.total,required this.color});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Column(children:[Row(children:[Expanded(child:Text(label,style:const TextStyle(fontWeight:FontWeight.w600))),Text('$count',style:const TextStyle(fontWeight:FontWeight.bold))]),const SizedBox(height:7),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:total==0?0:count/total,minHeight:9,backgroundColor:bg,color:color))]));}
class _StatusChip extends StatelessWidget {final String status;const _StatusChip(this.status);@override Widget build(BuildContext context){final color=status=='Available'?Colors.green:status=='Issued'?blue:Colors.red;return Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:color.withOpacity(.1),borderRadius:BorderRadius.circular(20)),child:Text(status,style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.bold)));}}

class _HeadsetDraft {
  Headset base;
  final TextEditingController brand;
  final TextEditingController serial;
  final TextEditingController assignedTo;
  final TextEditingController notes;
  final TextEditingController date;
  String status;
  DateTime createdAt;
  Timer? timer;

  _HeadsetDraft(Headset headset)
      : base=headset,
        brand=TextEditingController(text:headset.brand),
        serial=TextEditingController(text:headset.serial),
        assignedTo=TextEditingController(text:headset.assignedTo),
        notes=TextEditingController(text:headset.notes),
        date=TextEditingController(text:DateFormat('MM/dd/yyyy').format(headset.createdAt)),
        status=headset.status,
        createdAt=headset.createdAt;

  Headset toHeadset()=>Headset(
    id:base.id,tag:base.tag,brand:brand.text,model:base.model,serial:serial.text,
    status:status,assignedTo:assignedTo.text,department:base.department,
    notes:notes.text,createdAt:createdAt,
  );

  void dispose(){
    timer?.cancel();
    brand.dispose();
    serial.dispose();
    assignedTo.dispose();
    notes.dispose();
    date.dispose();
  }
}

class InventoryPage extends StatefulWidget {
  final InventoryStore store;
  final bool readOnly;
  const InventoryPage({super.key,required this.store,this.readOnly=false});
  @override State<InventoryPage> createState()=>_InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>{
  final Map<String,_HeadsetDraft> drafts={};
  String query='';
  String filter='All';

  @override
  void dispose(){
    for(final draft in drafts.values){draft.dispose();}
    super.dispose();
  }

  InputDecoration _cellDecoration({Widget? suffixIcon})=>InputDecoration(
    isDense:true,
    filled:true,
    fillColor:Colors.white,
    suffixIcon:suffixIcon,
    contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:12),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:Color(0xFFD9E3F3))),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:Color(0xFFD9E3F3))),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:const BorderSide(color:blue)),
  );

  Widget _textEditor(_HeadsetDraft draft,TextEditingController controller,{double width=150})=>SizedBox(
    width:width,
    child:TextField(
      controller:controller,
      readOnly:widget.readOnly,
      onChanged:widget.readOnly?null:(_)=>_queueSave(draft),
      onSubmitted:widget.readOnly?null:(_)=>_saveDraft(draft),
      decoration:_cellDecoration(),
    ),
  );

  void _queueSave(_HeadsetDraft draft){
    draft.timer?.cancel();
    draft.timer=Timer(const Duration(milliseconds:800),()=>_saveDraft(draft));
  }

  Future<void> _saveDraft(_HeadsetDraft draft) async{
    draft.timer?.cancel();
    draft.timer=null;
    if(widget.readOnly)return;
    try{
      final updated=draft.toHeadset();
      await widget.store.update(updated);
      draft.base=updated;
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Save failed: $e')));
    }
  }

  Future<void> _pickDate(_HeadsetDraft draft) async{
    if(widget.readOnly)return;
    final picked=await showDatePicker(context:context,initialDate:draft.createdAt,firstDate:DateTime(2000),lastDate:DateTime(2100));
    if(picked==null||!mounted)return;
    draft.createdAt=picked;
    draft.date.text=DateFormat('MM/dd/yyyy').format(picked);
    await _saveDraft(draft);
  }

  Widget _statusEditor(_HeadsetDraft draft)=>SizedBox(
    width:150,
    child:widget.readOnly
      ?InputDecorator(decoration:_cellDecoration(),child:Text(draft.status))
      :DropdownButtonFormField<String>(
        value:draft.status,
        decoration:_cellDecoration(),
        isExpanded:true,
        items:['Available','Issued','Defective'].map((value)=>DropdownMenuItem(value:value,child:Text(value))).toList(),
        onChanged:(value){
          if(value==null)return;
          draft.status=value;
          _saveDraft(draft);
        },
      ),
  );

  Widget _dateEditor(_HeadsetDraft draft)=>SizedBox(
    width:150,
    child:TextField(
      controller:draft.date,
      readOnly:true,
      onTap:widget.readOnly?null:()=>_pickDate(draft),
      decoration:_cellDecoration(suffixIcon:IconButton(
        onPressed:widget.readOnly?null:()=>_pickDate(draft),
        icon:const Icon(Icons.calendar_today,size:18),
      )),
    ),
  );

  @override
  Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.store,builder:(context,_){
    final rows=widget.store.items.where((headset)=>
      (filter=='All'||headset.status==filter)&&
      (headset.tag+' '+headset.brand+' '+headset.model+' '+headset.serial+' '+headset.assignedTo).toLowerCase().contains(query.toLowerCase())
    ).toList();
    for(final headset in rows){drafts.putIfAbsent(headset.id,()=>_HeadsetDraft(headset));}
    return Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Headset Inventory',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),
          Text('Manage headset assets and stock records',style:TextStyle(color:Colors.blueGrey)),
        ])),
        if(!widget.readOnly)FilledButton.icon(onPressed:_addHeadset,icon:const Icon(Icons.add),label:const Text('Add Headset')),
      ]),
      const SizedBox(height:18),
      Row(children:[
        Expanded(child:TextField(
          decoration:InputDecoration(
            prefixIcon:const Icon(Icons.search),
            hintText:'Search asset tag, brand, model, serial...',
            filled:true,
            fillColor:Colors.white,
            contentPadding:const EdgeInsets.symmetric(vertical:14),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:Color(0xFFD9E3F3))),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:Color(0xFFD9E3F3))),
          ),
          onChanged:(value)=>setState(()=>query=value),
        )),
        const SizedBox(width:12),
        SizedBox(width:145,child:DropdownButtonFormField<String>(
          value:filter,
          isExpanded:true,
          decoration:_cellDecoration(),
          items:['All','Available','Issued','Defective'].map((value)=>DropdownMenuItem(value:value,child:Text(value=='All'?'All Status':value))).toList(),
          onChanged:(value)=>setState(()=>filter=value??'All'),
        )),
      ]),
      const SizedBox(height:14),
      Expanded(child:Card(child:rows.isEmpty?const Center(child:Text('No headset records found.')):SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:SingleChildScrollView(child:DataTable(
          headingRowColor:const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
          horizontalMargin:16,
          columnSpacing:24,
          columns:[
            const DataColumn(label:Text('BRAND')),
            const DataColumn(label:Text('SERIAL')),
            const DataColumn(label:Text('AGENT NAME')),
            const DataColumn(label:Text('STATUS')),
            const DataColumn(label:Text('DATE')),
            const DataColumn(label:Text('REMARKS')),
            if(!widget.readOnly)const DataColumn(label:Text('REMOVE')),
          ],
          rows:rows.map((headset){
            final draft=drafts[headset.id]!;
            return DataRow(key:ValueKey(headset.id),cells:[
              DataCell(_textEditor(draft,draft.brand,width:180)),
              DataCell(_textEditor(draft,draft.serial,width:150)),
              DataCell(_textEditor(draft,draft.assignedTo,width:165)),
              DataCell(_statusEditor(draft)),
              DataCell(_dateEditor(draft)),
              DataCell(_textEditor(draft,draft.notes,width:150)),
              if(!widget.readOnly)DataCell(SizedBox(width:90,child:OutlinedButton(
                onPressed:()=>_remove(context,headset),
                style:OutlinedButton.styleFrom(
                  foregroundColor:Colors.red,
                  backgroundColor:const Color(0xFFFFF7F7),
                  side:BorderSide(color:Colors.red.shade200),
                  padding:const EdgeInsets.symmetric(horizontal:10,vertical:11),
                ),
                child:const Text('Remove'),
              ))),
            ]);
          }).toList(),
        )),
      ))),
    ]));
  });

  String _nextAssetTag(){
    final used=widget.store.items.map((headset)=>headset.tag).toSet();
    var number=widget.store.items.length+1;
    var tag='HS-${number.toString().padLeft(4,'0')}';
    while(used.contains(tag)){
      number++;
      tag='HS-${number.toString().padLeft(4,'0')}';
    }
    return tag;
  }

  Widget _addFormField(String label,TextEditingController controller,String hint)=>Padding(
    padding:const EdgeInsets.only(bottom:13),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:navy)),
      const SizedBox(height:6),
      TextField(controller:controller,decoration:InputDecoration(
        hintText:hint,isDense:true,filled:true,fillColor:Colors.white,
        contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:13),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFD9E3F3))),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:Color(0xFFD9E3F3))),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:blue)),
      )),
    ]),
  );

  Future<void> _addHeadset() async{
    if(widget.readOnly)return;
    final tag=TextEditingController(text:_nextAssetTag());
    final brand=TextEditingController();
    final model=TextEditingController();
    final serial=TextEditingController();
    final assignedTo=TextEditingController();
    final notes=TextEditingController();
    final date=TextEditingController(text:DateFormat('MM/dd/yyyy').format(DateTime.now()));
    var status='Available';
    var department='ONLINE';
    var createdAt=DateTime.now();
    final shouldSave=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>Dialog(
      child:SizedBox(width:420,child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          const Expanded(child:Text('Add Headset',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:navy))),
          IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(dialogContext,false),icon:const Icon(Icons.close,color:Colors.blueGrey)),
        ]),
        const SizedBox(height:8),
        _addFormField('Asset Tag',tag,'HS-0001'),
        _addFormField('Brand',brand,'e.g. Logitech, Jabra'),
        _addFormField('Model',model,'e.g. H570e, Evolve 20'),
        _addFormField('Serial Number',serial,'e.g. LGT-90211'),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Status',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:navy)),
          const SizedBox(height:6),
          DropdownButtonFormField<String>(
            value:status,decoration:_cellDecoration(),isExpanded:true,
            items:['Available','Issued','Defective'].map((value)=>DropdownMenuItem(value:value,child:Text(value))).toList(),
            onChanged:(value){if(value!=null)setDialogState(()=>status=value);},
          ),
        ]),
        const SizedBox(height:13),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Date',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:navy)),
          const SizedBox(height:6),
          TextField(
            controller:date,
            keyboardType:TextInputType.datetime,
            decoration:_cellDecoration(suffixIcon:IconButton(onPressed:()async{
            final picked=await showDatePicker(context:dialogContext,initialDate:createdAt,firstDate:DateTime(2000),lastDate:DateTime(2100));
            if(picked!=null)setDialogState(()=>date.text=DateFormat('MM/dd/yyyy').format(createdAt=picked));
          },icon:const Icon(Icons.calendar_today,size:18))),
          ),
        ]),
        const SizedBox(height:13),
        _addFormField('Assigned To',assignedTo,'Employee Name'),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Department',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:navy)),
          const SizedBox(height:6),
          DropdownButtonFormField<String>(
            value:department,decoration:_cellDecoration(),isExpanded:true,
            items:['ONLINE','BOOTH','SGM','UNO DIGITAL BANK'].map((value)=>DropdownMenuItem(value:value,child:Text(value))).toList(),
            onChanged:(value){if(value!=null)setDialogState(()=>department=value);},
          ),
        ]),
        _addFormField('Remarks / Notes',notes,'e.g. USB Headset, Wireless'),
        Row(mainAxisAlignment:MainAxisAlignment.end,children:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),
          const SizedBox(width:8),
          FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('Save Asset')),
        ]),
      ]))),
    )));
    if(shouldSave!=true||!mounted){
      tag.dispose();brand.dispose();model.dispose();serial.dispose();assignedTo.dispose();notes.dispose();date.dispose();
      return;
    }
    final enteredDate=DateFormat('MM/dd/yyyy').tryParseStrict(date.text.trim());
    if(enteredDate==null){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a valid date in MM/DD/YYYY format.')));
      tag.dispose();brand.dispose();model.dispose();serial.dispose();assignedTo.dispose();notes.dispose();date.dispose();
      return;
    }
    createdAt=enteredDate;
    if(tag.text.trim().isEmpty||brand.text.trim().isEmpty||model.text.trim().isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Asset Tag, Brand, and Model are required.')));
      tag.dispose();brand.dispose();model.dispose();serial.dispose();assignedTo.dispose();notes.dispose();date.dispose();
      return;
    }
    if(widget.store.items.any((headset)=>headset.tag.toLowerCase()==tag.text.trim().toLowerCase())){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Asset tag already exists.')));
      tag.dispose();brand.dispose();model.dispose();serial.dispose();assignedTo.dispose();notes.dispose();date.dispose();
      return;
    }
    final headset=Headset(
      id:DateTime.now().microsecondsSinceEpoch.toString(),tag:tag.text.trim(),brand:brand.text.trim(),model:model.text.trim(),
      serial:serial.text.trim(),status:status,assignedTo:assignedTo.text.trim(),department:department,
      notes:notes.text.trim(),createdAt:createdAt,
    );
    try{
      await widget.store.add(headset);
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Add failed: $e')));
    }finally{
      tag.dispose();brand.dispose();model.dispose();serial.dispose();assignedTo.dispose();notes.dispose();date.dispose();
    }
  }

  Future<void> _remove(BuildContext context,Headset headset) async{
    if(widget.readOnly)return;
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Remove headset?'),
      content:Text('Remove '+headset.tag+' from inventory?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Remove')),
      ],
    ));
    if(confirmed!=true||!context.mounted)return;
    try{
      drafts[headset.id]?.timer?.cancel();
      await widget.store.delete(headset);
      drafts.remove(headset.id)?.dispose();
    }catch(e){
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Remove failed: $e')));
    }
  }
}

class AssignmentsPage extends StatelessWidget {final InventoryStore store;const AssignmentsPage({super.key,required this.store});@override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){final assigned=store.items.where((h)=>h.status=='Issued').toList();return Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Assignments',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),const Text('Track headsets issued to employees',style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:20),Expanded(child:Card(child:ListView(children:assigned.map((h)=>ListTile(leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(h.assignedTo.isEmpty?'Employee not specified':h.assignedTo),subtitle:Text('${h.tag} • ${h.brand} ${h.model} • ${h.department}'),trailing:const _StatusChip('Issued'))).toList())))]));});}
class ReportsPage extends StatelessWidget {final InventoryStore store;const ReportsPage({super.key,required this.store});@override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){return Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Reports',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),const Text('Inventory summary',style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:20),_Panel(title:'Current Stock Summary',child:Column(children:['Available','Issued','Defective'].map((s){final n=store.items.where((h)=>h.status==s).length;return ListTile(title:Text(s),trailing:Text('$n',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)));}).toList()))]));});}
class SettingsPage extends StatelessWidget {const SettingsPage({super.key});@override Widget build(BuildContext context)=>const Padding(padding:EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Settings',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),SizedBox(height:16),Card(child:ListTile(leading:Icon(Icons.cloud_outlined),title:Text('Cloud database'),subtitle:Text('Inventory is saved to Cloudflare D1 and refreshes across open sessions.'))),Card(child:ListTile(leading:Icon(Icons.security_outlined),title:Text('Access control'),subtitle:Text('This public demo uses local login. Add server-side authentication before storing confidential inventory.')))]));}


// Local starter authentication. Viewer accounts are stored on this device.
// For secure multi-device cloud authentication, replace this with Supabase Auth.
class LoginGate extends StatefulWidget {
  const LoginGate({super.key});
  @override State<LoginGate> createState()=>_LoginGateState();
}
class _LoginGateState extends State<LoginGate> {
  final user=TextEditingController(), pass=TextEditingController();
  bool hide=true, busy=false, checkingSession=true; String error='';
  @override void initState(){super.initState();_restoreSession();}
  Future<void> _restoreSession() async{
    try{
      final prefs=await SharedPreferences.getInstance();
      final savedUser=prefs.getString('session_username');
      var valid=savedUser=='administrator';
      if(savedUser!=null&&!valid){
        final accounts=prefs.getStringList('viewer_accounts')??[];
        valid=accounts.any((account){final parts=account.split('|');return parts.length==2&&parts[0]==savedUser;});
      }
      if(valid&&mounted){
        Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>InventoryShell(username:savedUser!,isAdmin:savedUser=='administrator')));
        return;
      }
      if(savedUser!=null)await prefs.remove('session_username');
    }catch(_){}
    if(mounted)setState(()=>checkingSession=false);
  }
  Future<void> login() async {
    setState(()=>busy=true); error='';
    final prefs=await SharedPreferences.getInstance();
    final u=user.text.trim(), p=pass.text;
    bool ok=u=='administrator' && p=='P@ssw0rd';
    bool admin=ok;
    if(!ok){
      final users=prefs.getStringList('viewer_accounts')??[];
      for(final item in users){
        final parts=item.split('|');
        if(parts.length==2 && parts[0]==u && parts[1]==p){ok=true;break;}
      }
    }
    if(!mounted)return;
    setState(()=>busy=false);
    if(ok){
      await prefs.setString('session_username',u);
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>InventoryShell(username:u,isAdmin:admin)));
    }else setState(()=>error='Invalid username or password.');
  }
  @override Widget build(BuildContext context)=>checkingSession?const Scaffold(backgroundColor:bg,body:Center(child:CircularProgressIndicator())):Scaffold(backgroundColor:bg,body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Card(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const CompanyLogo(height:52),
    const SizedBox(height:18),const Text('HEADSET INVENTORY',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold,color:navy)),
    const SizedBox(height:5),const Text('Sign in to manage and view assets',style:TextStyle(color:Colors.blueGrey)),
    const SizedBox(height:28),TextField(controller:user,decoration:const InputDecoration(labelText:'Username',prefixIcon:Icon(Icons.person_outline),border:OutlineInputBorder()),onSubmitted:(_)=>login()),
    const SizedBox(height:14),TextField(controller:pass,obscureText:hide,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),border:const OutlineInputBorder(),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility:Icons.visibility_off))),onSubmitted:(_)=>login()),
    if(error.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text(error,style:const TextStyle(color:Colors.red))),
    const SizedBox(height:22),SizedBox(width:double.infinity,height:48,child:FilledButton(onPressed:busy?null:login,child:Text(busy?'Please wait...':'LOGIN'))),
    const SizedBox(height:14),const Text('Administrator access and view-only user access',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.blueGrey))
  ])))))));
}

class UsersPage extends StatefulWidget { const UsersPage({super.key}); @override State<UsersPage> createState()=>_UsersPageState(); }
class _UsersPageState extends State<UsersPage>{
  List<String> users=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {final p=await SharedPreferences.getInstance();if(mounted)setState(()=>users=p.getStringList('viewer_accounts')??[]);}
  Future<void> _add() async {
    final u=TextEditingController(),p=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Add View-Only User'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:u,decoration:const InputDecoration(labelText:'Username')),
      const SizedBox(height:12),TextField(controller:p,decoration:const InputDecoration(labelText:'Temporary password'))
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create User'))]));
    if(ok==true && u.text.trim().isNotEmpty && p.text.isNotEmpty){
      final prefs=await SharedPreferences.getInstance();final list=prefs.getStringList('viewer_accounts')??[];
      if(u.text.trim()=='administrator'||list.any((x)=>x.split('|').first==u.text.trim())){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Username already exists.')));return;
      }
      list.add('${u.text.trim()}|${p.text}');await prefs.setStringList('viewer_accounts',list);_load();
    }
  }
  Future<void> _remove(String item) async {final p=await SharedPreferences.getInstance();users.remove(item);await p.setStringList('viewer_accounts',users);if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('User Management',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),Text('Create accounts with view-only permissions',style:TextStyle(color:Colors.blueGrey))])),FilledButton.icon(onPressed:_add,icon:const Icon(Icons.person_add_alt_1),label:const Text('Add User'))]),
    const SizedBox(height:20),Expanded(child:Card(child:ListView(children:[
      const ListTile(leading:CircleAvatar(child:Icon(Icons.admin_panel_settings)),title:Text('administrator'),subtitle:Text('Administrator • Full access'),trailing:Chip(label:Text('Admin'))),
      const Divider(height:1),
      ...users.map((item){final name=item.split('|').first;return ListTile(leading:const CircleAvatar(child:Icon(Icons.visibility_outlined)),title:Text(name),subtitle:const Text('Viewer • Read-only access'),trailing:IconButton(tooltip:'Remove user',onPressed:()=>_remove(item),icon:const Icon(Icons.delete_outline,color:Colors.red)));})
    ])))
  ]));
}

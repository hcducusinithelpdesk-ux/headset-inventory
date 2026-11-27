import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const navy = Color(0xFF092B61);
const blue = Color(0xFF1265D8);
const bg = Color(0xFFF4F7FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
  }
  runApp(const HeadsetApp());
}

bool get cloudReady {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  return url.isNotEmpty && key.isNotEmpty;
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
    'department':department,'notes':notes};
}

class InventoryStore extends ChangeNotifier {
  final List<Headset> items = [
    Headset(id:'1',tag:'HS-0001',brand:'Logitech',model:'H570e',serial:'LGT-90211',status:'Available',assignedTo:'',department:'',notes:'USB headset',createdAt:DateTime.now()),
    Headset(id:'2',tag:'HS-0002',brand:'Jabra',model:'Evolve 20',serial:'JBR-11208',status:'Issued',assignedTo:'Maria Santos',department:'IT Support',notes:'',createdAt:DateTime.now()),
    Headset(id:'3',tag:'HS-0003',brand:'Plantronics',model:'Blackwire 3320',serial:'PLT-33021',status:'Defective',assignedTo:'',department:'',notes:'Mic not working',createdAt:DateTime.now()),
    Headset(id:'4',tag:'HS-0004',brand:'Logitech',model:'H390',serial:'LGT-77401',status:'Available',assignedTo:'',department:'',notes:'',createdAt:DateTime.now()),
    Headset(id:'5',tag:'HS-0005',brand:'Jabra',model:'Evolve 65',serial:'JBR-65003',status:'Issued',assignedTo:'Juan Dela Cruz',department:'Sales',notes:'Wireless',createdAt:DateTime.now()),
  ];
  bool get online => cloudReady;
  Future<void> load() async {
    if (!online) return;
    try {
      final rows = await Supabase.instance.client.from('headsets').select().order('created_at',ascending:false);
      items..clear()..addAll(rows.map((e)=>Headset.fromMap(e)));
      notifyListeners();
    } catch (_) {}
  }
  Future<void> add(Headset h) async {
    if (online) {
      final row = await Supabase.instance.client.from('headsets').insert(h.toMap()).select().single();
      items.insert(0,Headset.fromMap(row));
    } else { items.insert(0,h); }
    notifyListeners();
  }
  Future<void> update(Headset h) async {
    if (online) {
      final row = await Supabase.instance.client.from('headsets').update(h.toMap()).eq('id',h.id).select().single();
      final i=items.indexWhere((x)=>x.id==h.id); if(i>=0) items[i]=Headset.fromMap(row);
    } else { final i=items.indexWhere((x)=>x.id==h.id); if(i>=0) items[i]=h; }
    notifyListeners();
  }
  Future<void> delete(Headset h) async {
    if (online) await Supabase.instance.client.from('headsets').delete().eq('id',h.id);
    items.removeWhere((x)=>x.id==h.id); notifyListeners();
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
  void _logout(){
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder:(_)=>const LoginGate()),
      (route)=>false,
    );
  }
  @override Widget build(BuildContext context) {
    final wide=MediaQuery.sizeOf(context).width>800;
    final pages=[DashboardPage(store:store,onInventory:()=>setState(()=>page=1)),
      InventoryPage(store:store,readOnly:!widget.isAdmin), AssignmentsPage(store:store), ReportsPage(store:store), const SettingsPage(),
      if(widget.isAdmin) UsersPage()];
    return Scaffold(body:Row(children:[
      if(wide) _Sidebar(page:page,onSelect:(v)=>setState(()=>page=v),isAdmin:widget.isAdmin),
      Expanded(child:Column(children:[
        _Topbar(online:store.online,username:widget.username,onLogout:_logout,onMenu:wide?null:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Use the bottom navigation to switch pages.')))),
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
 final InventoryStore store; final VoidCallback onInventory;
 const DashboardPage({super.key,required this.store,required this.onInventory});
 @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
  final total=store.items.length,available=store.items.where((x)=>x.status=='Available').length,issued=store.items.where((x)=>x.status=='Issued').length,defective=store.items.where((x)=>x.status=='Defective').length;
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
      const SizedBox(height:22),SizedBox(height:150,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:List.generate(6,(i){
        final n=(total*(.55+i*.09)).round();return Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:5),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
          Container(height:(n==0?4.0:n.toDouble()).clamp(4.0,125.0).toDouble(),decoration:BoxDecoration(color:blue.withOpacity(.85),borderRadius:BorderRadius.circular(5))),
          const SizedBox(height:8),Text(['Jun','Jul','Aug','Sep','Oct','Nov'][i],style:const TextStyle(fontSize:11,color:Colors.blueGrey))
        ])));
      })))
    ]))),
    SizedBox(width:c.maxWidth>950?c.maxWidth*.39:c.maxWidth,child:_Panel(title:'Headset Status',child:Column(children:[
      _StatusBar(label:'Available',count:available,total:total,color:const Color(0xFF10A779)),
      _StatusBar(label:'Issued',count:issued,total:total,color:blue),
      _StatusBar(label:'Defective',count:defective,total:total,color:const Color(0xFFE3485B)),
      const SizedBox(height:12),Text('$total total assets',style:const TextStyle(fontSize:12,color:Colors.blueGrey))
    ])))
   ])),
   const SizedBox(height:20),_Panel(title:'Recent Inventory Activity',action:TextButton(onPressed:onInventory,child:const Text('View Inventory →')),child:Column(children:[
    for(final h in store.items.take(5)) ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(backgroundColor:const Color(0xFFEAF1FC),child:const Icon(Icons.headset,color:blue)),title:Text('${h.tag}  •  ${h.brand} ${h.model}',style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text(h.assignedTo.isEmpty?'Not assigned':h.assignedTo),trailing:_StatusChip(h.status))
   ]))
  ]));
 });
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

class InventoryPage extends StatefulWidget {final InventoryStore store; final bool readOnly; const InventoryPage({super.key,required this.store, this.readOnly=false});@override State<InventoryPage> createState()=>_InventoryPageState();}
class _InventoryPageState extends State<InventoryPage>{
 String query='';String filter='All';
 @override Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.store,builder:(context,_){
  final rows=widget.store.items.where((h)=>(filter=='All'||h.status==filter)&&('${h.tag} ${h.brand} ${h.model} ${h.serial}'.toLowerCase().contains(query.toLowerCase()))).toList();
  return Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Headset Inventory',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),Text('Manage headset assets and stock records',style:TextStyle(color:Colors.blueGrey))])),if(!widget.readOnly) FilledButton.icon(onPressed:()=>_edit(context),icon:const Icon(Icons.add),label:const Text('Add Headset'))]),
   const SizedBox(height:18),Row(children:[Expanded(child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search asset tag, brand, model...',filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.all(Radius.circular(12)))),onChanged:(v)=>setState(()=>query=v))),const SizedBox(width:12),DropdownButton<String>(value:filter,items:['All','Available','Issued','Defective'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>filter=v!))]),
   const SizedBox(height:14),Expanded(child:Card(child:rows.isEmpty?const Center(child:Text('No headset records found.')):SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(columns:[
    const DataColumn(label:Text('BRAND')),const DataColumn(label:Text('SERIAL')),const DataColumn(label:Text('AGENT NAME')),const DataColumn(label:Text('STATUS')),const DataColumn(label:Text('DATE')),const DataColumn(label:Text('REMARKS')),
    if(!widget.readOnly) const DataColumn(label:Text('REMOVE')),
   ],rows:rows.map((h)=>DataRow(cells:[
    DataCell(Text(h.brand)),DataCell(Text(h.serial.isEmpty?'—':h.serial)),DataCell(Text(h.assignedTo.isEmpty?'—':h.assignedTo)),DataCell(_StatusChip(h.status)),DataCell(Text(DateFormat.yMd().format(h.createdAt))),DataCell(Text(h.notes.isEmpty?'—':h.notes)),
    if(!widget.readOnly) DataCell(TextButton(onPressed:()=>_remove(context,h),style:TextButton.styleFrom(foregroundColor:Colors.red),child:const Text('Remove'))),
   ])).toList())))))
  ]));
 });
 Future<void> _remove(BuildContext context,Headset headset) async {
  if(widget.readOnly)return;
  final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Remove headset?'),
   content:Text('Remove ${headset.tag} from inventory?'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Remove')),
   ],
  ));
  if(confirmed!=true||!context.mounted)return;
  try{await widget.store.delete(headset);}catch(e){
   if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Remove failed: $e')));
  }
 }
 Future<void> _edit(BuildContext context,[Headset? h]) async{
  final tag=TextEditingController(text:h?.tag??'HS-${(widget.store.items.length+1).toString().padLeft(4,'0')}'),brand=TextEditingController(text:h?.brand??''),model=TextEditingController(text:h?.model??''),serial=TextEditingController(text:h?.serial??''),person=TextEditingController(text:h?.assignedTo??''),dept=TextEditingController(text:h?.department??''),notes=TextEditingController(text:h?.notes??'');
  String status=h?.status??'Available';
  DateTime selectedDate=h?.createdAt??DateTime.now();
  await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:Text(h==null?'Add Headset':'Edit Headset'),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   for(final pair in [('Asset Tag',tag),('Brand',brand),('Model',model),('Serial Number',serial),('Assigned To',person),('Department',dept),('Remarks',notes)]) Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:pair.$2,decoration:InputDecoration(labelText:pair.$1,border:const OutlineInputBorder()))),
   DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Status'),items:['Available','Issued','Defective'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>setD(()=>status=v!)),
   const SizedBox(height:10),InkWell(onTap:()async{final picked=await showDatePicker(context:ctx,initialDate:selectedDate,firstDate:DateTime(2000),lastDate:DateTime(2100));if(picked!=null)setD(()=>selectedDate=picked);},child:InputDecorator(decoration:const InputDecoration(labelText:'Date',border:OutlineInputBorder(),suffixIcon:Icon(Icons.calendar_today)),child:Text(DateFormat.yMd().format(selectedDate))))
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()async{
   final item=Headset(id:h?.id??DateTime.now().microsecondsSinceEpoch.toString(),tag:tag.text,brand:brand.text,model:model.text,serial:serial.text,status:status,assignedTo:person.text,department:dept.text,notes:notes.text,createdAt:selectedDate);
   try{if(h==null)await widget.store.add(item);else await widget.store.update(item);if(ctx.mounted)Navigator.pop(ctx);}catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Save failed: $e')));}
  },child:const Text('Save'))])));
 }
}

class AssignmentsPage extends StatelessWidget {final InventoryStore store;const AssignmentsPage({super.key,required this.store});@override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){final assigned=store.items.where((h)=>h.status=='Issued').toList();return Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Assignments',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),const Text('Track headsets issued to employees',style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:20),Expanded(child:Card(child:ListView(children:assigned.map((h)=>ListTile(leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(h.assignedTo.isEmpty?'Employee not specified':h.assignedTo),subtitle:Text('${h.tag} • ${h.brand} ${h.model} • ${h.department}'),trailing:const _StatusChip('Issued'))).toList())))]));});}
class ReportsPage extends StatelessWidget {final InventoryStore store;const ReportsPage({super.key,required this.store});@override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){return Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Reports',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),const Text('Inventory summary',style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:20),_Panel(title:'Current Stock Summary',child:Column(children:['Available','Issued','Defective'].map((s){final n=store.items.where((h)=>h.status==s).length;return ListTile(title:Text(s),trailing:Text('$n',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)));}).toList()))]));});}
class SettingsPage extends StatelessWidget {const SettingsPage({super.key});@override Widget build(BuildContext context)=>const Padding(padding:EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Settings',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:navy)),SizedBox(height:16),Card(child:ListTile(leading:Icon(Icons.cloud_outlined),title:Text('Cloud database'),subtitle:Text('Connect a Supabase project using the setup guide in README.md.'))),Card(child:ListTile(leading:Icon(Icons.security_outlined),title:Text('Access control'),subtitle:Text('Enable Supabase Auth and Row Level Security before production use.')))]));}


// Local starter authentication. Viewer accounts are stored on this device.
// For secure multi-device cloud authentication, replace this with Supabase Auth.
class LoginGate extends StatefulWidget {
  const LoginGate({super.key});
  @override State<LoginGate> createState()=>_LoginGateState();
}
class _LoginGateState extends State<LoginGate> {
  final user=TextEditingController(), pass=TextEditingController();
  bool hide=true, busy=false; String error='';
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
    if(ok) Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>InventoryShell(username:u,isAdmin:admin)));
    else setState(()=>error='Invalid username or password.');
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:bg,body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Card(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,children:[
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

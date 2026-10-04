import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const LinageApp());

class LinageApp extends StatelessWidget {
  const LinageApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linage Proot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5CFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B10),
      ),
      home: const Root(),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const HomePage(), const SubsPage(), const SettingsPage()];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(CupertinoIcons.home), label: 'Дом'),
          NavigationDestination(icon: Icon(CupertinoIcons.link), label: 'Подписки'),
          NavigationDestination(icon: Icon(CupertinoIcons.gear), label: 'Настройки'),
        ],
      ),
    );
  }
}

// ============ МОДЕЛЬ ============
class VServer {
  final String name;
  final String proto;
  final String host;
  final int port;
  final String raw;
  VServer({required this.name, required this.proto, required this.host, required this.port, required this.raw});
}

// ============ ПАРСЕР ============
class SubParser {
  static List<VServer> parse(String input) {
    final out = <VServer>[];
    var text = input.trim();
    // Попытка base64 (стандарт подписки)
    if (!text.contains('://')) {
      try {
        final dec = utf8.decode(base64.decode(base64.normalize(text)));
        text = dec;
      } catch (_) {}
    }
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final l = line.trim();
      if (l.isEmpty) continue;
      if (l.startsWith('vless://')) out.add(_vless(l));
      else if (l.startsWith('trojan://')) out.add(_trojan(l));
      else if (l.startsWith('ss://')) out.add(_ss(l));
      else if (l.startsWith('vmess://')) out.add(_vmess(l));
    }
    return out;
  }

  static VServer _vless(String raw) {
    final u = Uri.parse(raw);
    return VServer(
      name: u.fragment.isNotEmpty ? u.fragment : 'VLESS',
      proto: 'vless',
      host: u.host,
      port: u.port == 0 ? 443 : u.port,
      raw: raw,
    );
  }

  static VServer _trojan(String raw) {
    final u = Uri.parse(raw);
    return VServer(
      name: u.fragment.isNotEmpty ? u.fragment : 'Trojan',
      proto: 'trojan',
      host: u.host,
      port: u.port == 0 ? 443 : u.port,
      raw: raw,
    );
  }

  static VServer _ss(String raw) {
    try {
      var body = raw.substring('ss://'.length);
      String? frag;
      if (body.contains('#')) {
        final p = body.split('#');
        body = p[0];
        frag = Uri.decodeComponent(p[1]);
      }
      String host = '', pass = '';
      int port = 0;
      if (body.contains('@')) {
        final dec = utf8.decode(base64.decode(base64.normalize(body.split('@')[0])));
        final hp = body.split('@')[1];
        pass = dec;
        final parts = hp.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? 0;
      } else {
        final dec = utf8.decode(base64.decode(base64.normalize(body)));
        final at = dec.split('@');
        pass = at[0];
        final hp = at[1].split(':');
        host = hp[0];
        port = int.tryParse(hp[1]) ?? 0;
      }
      return VServer(name: frag ?? 'Shadowsocks', proto: 'ss', host: host, port: port, raw: raw);
    } catch (_) {
      return VServer(name: 'SS (bad)', proto: 'ss', host: '', port: 0, raw: raw);
    }
  }

  static VServer _vmess(String raw) {
    try {
      final body = raw.substring('vmess://'.length);
      final j = jsonDecode(utf8.decode(base64.decode(base64.normalize(body))));
      return VServer(
        name: (j['ps'] ?? 'VMess').toString(),
        proto: 'vmess',
        host: (j['add'] ?? '').toString(),
        port: int.tryParse((j['port'] ?? '0').toString()) ?? 0,
        raw: raw,
      );
    } catch (_) {
      return VServer(name: 'VMess (bad)', proto: 'vmess', host: '', port: 0, raw: raw);
    }
  }
}

// ============ ХРАНИЛИЩЕ ============
class Store {
  static const _kSubs = 'subs';
  static Future<List<String>> getSubs() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_kSubs) ?? [];
  }
  static Future<void> setSubs(List<String> v) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSubs, v);
  }
}

// ============ ЭКРАН: ДОМ ============
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<VServer> _servers = [];
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await Store.getSubs();
    final all = <VServer>[];
    for (final s in subs) all.addAll(SubParser.parse(s));
    if (mounted) setState(() => _servers = all);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text('Linage Proot', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${_servers.length} серверов', style: const TextStyle(color: Colors.white54)),
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _connected = !_connected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _connected
                          ? [const Color(0xFF7C5CFF), const Color(0xFF36D1DC)]
                          : [const Color(0xFF1A1A22), const Color(0xFF1A1A22)],
                    ),
                    boxShadow: _connected
                        ? [BoxShadow(color: const Color(0xFF7C5CFF).withOpacity(0.5), blurRadius: 40, spreadRadius: 8)]
                        : [],
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.power,
                      size: 72,
                      color: _connected ? Colors.white : Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              _connected ? 'Подключено' : 'Отключено',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ============ ЭКРАН: ПОДПИСКИ ============
class SubsPage extends StatefulWidget {
  const SubsPage({super.key});
  @override
  State<SubsPage> createState() => _SubsPageState();
}

class _SubsPageState extends State<SubsPage> {
  final _ctrl = TextEditingController();
  List<String> _subs = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await Store.getSubs();
    if (mounted) setState(() => _subs = s);
  }

  Future<void> _add() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    _subs.add(v);
    await Store.setSubs(_subs);
    _ctrl.clear();
    setState(() {});
  }

  Future<void> _addUrl() async {
    final v = _ctrl.text.trim();
    if (!v.startsWith('http')) return;
    try {
      final r = await http.get(Uri.parse(v));
      if (r.statusCode == 200) {
        _subs.add(r.body);
        await Store.setSubs(_subs);
        _ctrl.clear();
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _del(int i) async {
    _subs.removeAt(i);
    await Store.setSubs(_subs);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text('Подписки', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'vless://... или https://подписка',
                filled: true,
                fillColor: const Color(0xFF1A1A22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: _add, child: const Text('Добавить')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(onPressed: _addUrl, child: const Text('Из URL')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _subs.isEmpty
                  ? const Center(child: Text('Пусто', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: _subs.length,
                      itemBuilder: (c, i) => Card(
                        color: const Color(0xFF14141B),
                        child: ListTile(
                          title: Text('Подписка ${i + 1}'),
                          subtitle: Text(
                            _subs[i].length > 60 ? '${_subs[i].substring(0, 60)}...' : _subs[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(CupertinoIcons.trash),
                            onPressed: () => _del(i),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ЭКРАН: НАСТРОЙКИ ============
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SizedBox(height: 8),
            Text('Настройки', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Раздельное туннелирование'),
              subtitle: Text('Скоро', style: TextStyle(color: Colors.white38)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Тема'),
              subtitle: Text('iOS 27 (тёмная)', style: TextStyle(color: Colors.white38)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('О приложении'),
              subtitle: Text('Linage Proot v0.1.0', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}

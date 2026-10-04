import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ============ ГЛОБАЛЬНОЕ СОСТОЯНИЕ ============
final subsState = ValueNotifier<List<String>>([]);
final serversState = ValueNotifier<List<VServer>>([]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.load();
  runApp(const LinageApp());
}

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
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9B7BFF),
          secondary: Color(0xFF6DD5FA),
          surface: Color(0xFF14141B),
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const Root(),
    );
  }
}

// ============ ГЛАСС-ФОН ============
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8, -1.0),
              radius: 1.6,
              colors: [Color(0xFF3B2A7A), Color(0xFF0B0B10)],
            ),
          ),
        ),
        Positioned(
          top: -100, right: -80,
          child: _blob(const Color(0xFF7C5CFF), 320),
        ),
        Positioned(
          bottom: -120, left: -100,
          child: _blob(const Color(0xFF36D1DC), 300),
        ),
        child,
      ],
    );
  }

  Widget _blob(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [c.withOpacity(0.55), c.withOpacity(0.0)],
          ),
        ),
      );
}

// ============ ГЛАСС-КАРТОЧКА ============
class Glass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsets? padding;
  final BorderRadius? radius;
  const Glass({
    super.key,
    required this.child,
    this.blur = 24,
    this.opacity = 0.06,
    this.padding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final br = radius ?? BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: br,
            border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============ ROOT ============
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
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: pages[_idx],
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Glass(
            radius: BorderRadius.circular(28),
            blur: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: const Color(0xFF9B7BFF).withOpacity(0.25),
                labelTextStyle: MaterialStateProperty.all(
                  const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
              child: NavigationBar(
                height: 64,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _idx,
                onDestinationSelected: (i) => setState(() => _idx = i),
                destinations: const [
                  NavigationDestination(icon: Icon(CupertinoIcons.house_fill), label: 'Дом'),
                  NavigationDestination(icon: Icon(CupertinoIcons.link), label: 'Подписки'),
                  NavigationDestination(icon: Icon(CupertinoIcons.gear_alt_fill), label: 'Ещё'),
                ],
              ),
            ),
          ),
        ),
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
    if (text.isEmpty) return out;
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
    try {
      final u = Uri.parse(raw);
      return VServer(
        name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : 'VLESS'),
        proto: 'vless',
        host: u.host,
        port: u.port == 0 ? 443 : u.port,
        raw: raw,
      );
    } catch (_) {
      return VServer(name: 'VLESS', proto: 'vless', host: '', port: 0, raw: raw);
    }
  }

  static VServer _trojan(String raw) {
    try {
      final u = Uri.parse(raw);
      return VServer(
        name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : 'Trojan'),
        proto: 'trojan', host: u.host, port: u.port == 0 ? 443 : u.port, raw: raw,
      );
    } catch (_) {
      return VServer(name: 'Trojan', proto: 'trojan', host: '', port: 0, raw: raw);
    }
  }

  static VServer _ss(String raw) {
    try {
      var body = raw.substring(5);
      String? frag;
      if (body.contains('#')) {
        final p = body.split('#');
        body = p[0];
        frag = Uri.decodeComponent(p[1]);
      }
      body = body.split('?')[0];
      String host = '', port = '0';
      if (body.contains('@')) {
        final hp = body.split('@')[1];
        final parts = hp.split(':');
        host = parts[0];
        port = parts.length > 1 ? parts[1] : '0';
      } else {
        final dec = utf8.decode(base64.decode(base64.normalize(body)));
        final at = dec.split('@');
        final hp = at.last.split(':');
        host = hp[0];
        port = hp.length > 1 ? hp[1] : '0';
      }
      return VServer(name: frag ?? 'Shadowsocks', proto: 'ss', host: host, port: int.tryParse(port) ?? 0, raw: raw);
    } catch (_) {
      return VServer(name: 'SS', proto: 'ss', host: '', port: 0, raw: raw);
    }
  }

  static VServer _vmess(String raw) {
    try {
      final body = raw.substring(8);
      final j = jsonDecode(utf8.decode(base64.decode(base64.normalize(body))));
      return VServer(
        name: (j['ps'] ?? 'VMess').toString(),
        proto: 'vmess',
        host: (j['add'] ?? '').toString(),
        port: int.tryParse((j['port'] ?? '0').toString()) ?? 0,
        raw: raw,
      );
    } catch (_) {
      return VServer(name: 'VMess', proto: 'vmess', host: '', port: 0, raw: raw);
    }
  }
}

// ============ ХРАНИЛИЩЕ ============
class Store {
  static const _kSubs = 'subs';
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getStringList(_kSubs) ?? [];
    subsState.value = s;
    _reparse();
  }
  static Future<void> save(List<String> v) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSubs, v);
    subsState.value = List.from(v);
    _reparse();
  }
  static void _reparse() {
    final all = <VServer>[];
    for (final s in subsState.value) {
      all.addAll(SubParser.parse(s));
    }
    serversState.value = all;
  }
}

// ============ HOME ============
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Linage', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B7BFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PROOT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9B7BFF), letterSpacing: 1.5)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder(
              valueListenable: serversState,
              builder: (c, v, _) => Text(
                v.isEmpty ? 'нет серверов' : '${v.length} серверов',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _connected = !_connected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _connected
                        ? const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF9B7BFF), Color(0xFF6DD5FA)],
                          )
                        : null,
                    color: _connected ? null : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: _connected ? Colors.transparent : Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: _connected
                        ? [
                            BoxShadow(color: const Color(0xFF9B7BFF).withOpacity(0.55), blurRadius: 60, spreadRadius: 6),
                            BoxShadow(color: const Color(0xFF6DD5FA).withOpacity(0.30), blurRadius: 90, spreadRadius: 10),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.power,
                      size: 76,
                      color: _connected ? Colors.white : Colors.white.withOpacity(0.35),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Glass(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text(
                    _connected ? 'Подключено' : 'Отключено',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _connected ? 'весь трафик через туннель' : 'нажми кнопку чтобы начать',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ SUBS ============
class SubsPage extends StatefulWidget {
  const SubsPage({super.key});
  @override
  State<SubsPage> createState() => _SubsPageState();
}

class _SubsPageState extends State<SubsPage> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.redAccent.withOpacity(0.9) : const Color(0xFF9B7BFF).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _add() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      _toast('Вставь ссылку или URL подписки', err: true);
      return;
    }
    setState(() => _busy = true);
    try {
      String content = v;
      if (v.startsWith('http://') || v.startsWith('https://')) {
        final r = await http.get(Uri.parse(v)).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) {
          _toast('HTTP ${r.statusCode}', err: true);
          return;
        }
        content = r.body;
      }
      final parsed = SubParser.parse(content);
      if (parsed.isEmpty) {
        _toast('Не нашёл серверов', err: true);
        return;
      }
      final list = List<String>.from(subsState.value);
      list.add(content);
      await Store.save(list);
      _ctrl.clear();
      _toast('Добавлено: ${parsed.length} серверов');
    } catch (e) {
      _toast('Ошибка: $e', err: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _del(int i) async {
    final list = List<String>.from(subsState.value);
    list.removeAt(i);
    await Store.save(list);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Подписки', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            ValueListenableBuilder(
              valueListenable: subsState,
              builder: (c, v, _) => Text(
                v.isEmpty ? 'список пуст' : '${v.length} шт.',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Glass(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _ctrl,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'vless://... / trojan://... / https://подписка',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _add,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9B7BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: Glass(
                    radius: BorderRadius.circular(16),
                    padding: EdgeInsets.zero,
                    child: IconButton(
                      icon: const Icon(CupertinoIcons.doc_on_clipboard),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          setState(() => _ctrl.text = data!.text!);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: serversState,
                builder: (c, v, _) {
                  if (v.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.link, size: 48, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 12),
                          Text('Вставь подписку выше', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: v.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final s = v[i];
                      return Glass(
                        radius: BorderRadius.circular(18),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9B7BFF).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  s.proto.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9B7BFF)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('${s.host}:${s.port}', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ SETTINGS ============
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ещё', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const SizedBox(height: 20),
            _tile(context, CupertinoIcons.shield_lefthalf_fill, 'Раздельное туннелирование', 'скоро'),
            const SizedBox(height: 10),
            _tile(context, CupertinoIcons.paintbrush, 'Внешний вид', 'Aurora Glass'),
            const SizedBox(height: 10),
            _tile(context, CupertinoIcons.info_circle, 'О приложении', 'Linage Proot 0.2.0'),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext c, IconData icon, String title, String sub) {
    return Glass(
      radius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF9B7BFF)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45))),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.white.withOpacity(0.3)),
        ],
      ),
    );
  }
}

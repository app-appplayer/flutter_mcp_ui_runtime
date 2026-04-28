import 'dart:convert';
import 'dart:io';

/// Dumps each page JSON from the server to test/fixtures/ for rendering tests.
void main() async {
  final fixtureDir = Directory('test/fixtures');
  if (!fixtureDir.existsSync()) fixtureDir.createSync(recursive: true);

  final server = await Process.start('./server', []);
  server.stderr.transform(utf8.decoder).listen((_) {});

  final responses = <int, Map<String, dynamic>>{};
  int nextId = 1;

  server.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final id = json['id'] as int?;
      if (id != null) responses[id] = json;
    } catch (_) {}
  });

  void send(Map<String, dynamic> msg) => server.stdin.writeln(jsonEncode(msg));

  Future<Map<String, dynamic>?> request(String method, Map<String, dynamic> params) async {
    final id = nextId++;
    send({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (responses.containsKey(id)) return responses.remove(id);
    }
    return null;
  }

  await request('initialize', {
    'protocolVersion': '2024-11-05',
    'capabilities': {},
    'clientInfo': {'name': 'dump', 'version': '1.0'},
  });
  send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
  await Future.delayed(const Duration(milliseconds: 500));

  // Dump app definition
  final appResp = await request('resources/read', {'uri': 'ui://app'});
  final appText = appResp?['result']?['contents']?[0]?['text'] as String;
  File('test/fixtures/app.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(jsonDecode(appText)));

  final appDef = jsonDecode(appText) as Map<String, dynamic>;
  final routes = appDef['routes'] as Map<String, dynamic>;

  // Dump each page
  for (final entry in routes.entries) {
    final name = entry.key.replaceAll('/', '');
    final uri = entry.value as String;
    final resp = await request('resources/read', {'uri': uri});
    final text = resp?['result']?['contents']?[0]?['text'] as String;
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    File('test/fixtures/$name.json').writeAsStringSync(pretty);
    stderr.writeln('Saved: test/fixtures/$name.json');
  }

  server.kill();
  exit(0);
}

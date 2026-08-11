// `CacheManager`'s persistence and `PluginHookManager`'s teardown.
//
// Both are places where a failure has to stay quiet without becoming
// invisible: a store that will not persist must not take the write down with
// it, and a hook that throws must not stop the ones behind it. The quiet part
// is what makes them worth pinning — a swallowed error and a working system
// look identical until the next restart.

import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_hooks.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheManager persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('state survives into a second manager through the store', () async {
      final first = CacheManager(enableDebugMode: true);
      await first.cacheState('example.com:jobs', <String, dynamic>{'tab': 2});

      final second = CacheManager(enableDebugMode: true);
      await second.loadPersistedState('example.com:jobs');

      expect(second.getCachedState('example.com:jobs'), <String, dynamic>{
        'tab': 2,
      }, reason: 'the persisted copy is what makes a restart resume where the '
          'user was; a cache that only lives in memory is a variable');
    });

    test('a state that cannot be encoded is not written, and does not throw',
        () async {
      final manager = CacheManager(enableDebugMode: true);

      // A function is not JSON: the encode throws inside the persist step.
      await manager.cacheState('example.com:jobs', <String, dynamic>{
        'callback': () {},
      });

      expect(manager.getCachedState('example.com:jobs'), isNotNull,
          reason: 'the in-memory copy is still good; only the persist failed, '
              'and taking the whole write down for that would lose the '
              'session as well as the restart');
    });

    test('a stored value that will not parse is ignored on load', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mcp_ui_state_example.com:jobs': 'not json',
      });
      final manager = CacheManager(enableDebugMode: true);

      await manager.loadPersistedState('example.com:jobs');

      expect(manager.getCachedState('example.com:jobs'), isNull,
          reason: 'a half-written store is not state; loading it as one puts '
              'a document into a shape it never wrote');
    });

    test('clearing removes what was persisted', () async {
      final manager = CacheManager(enableDebugMode: true);
      await manager.cacheState('example.com:jobs', <String, dynamic>{'a': 1});

      await manager.clearAll();

      final second = CacheManager(enableDebugMode: true);
      await second.loadPersistedState('example.com:jobs');
      expect(second.getCachedState('example.com:jobs'), isNull);
    });
  });

  group('PluginHookManager', () {
    tearDown(PluginHookManager.instance.clear);

    test('one hook that throws does not stop the ones behind it', () async {
      final ran = <String>[];
      PluginHookManager.instance.registerHook(
        pluginName: 'noisy',
        hookType: PluginHookType.onError,
        callback: (data) async => throw StateError('hook broke'),
      );
      PluginHookManager.instance.registerHook(
        pluginName: 'quiet',
        hookType: PluginHookType.onError,
        callback: (data) async => ran.add('quiet'),
      );

      PluginHookManager.instance
          .fireHookSync(PluginHookType.onError, data: <String, dynamic>{});
      await Future<void>.delayed(Duration.zero);

      expect(ran, contains('quiet'),
          reason: 'a plugin that throws in a hook must not silence every '
              'plugin registered after it');
    });

    test('clear removes every hook, and dispose is quiet after it', () {
      PluginHookManager.instance.registerHook(
        pluginName: 'p',
        hookType: PluginHookType.onError,
        callback: (data) async {},
      );

      PluginHookManager.instance.clear();
      PluginHookManager.instance.dispose();

      // Firing after teardown reaches nobody and must not throw.
      PluginHookManager.instance
          .fireHookSync(PluginHookType.onError, data: <String, dynamic>{});
    });
  });
}

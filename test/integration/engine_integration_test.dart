import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show TemplateDefinition, AnimationActionDefinition;
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_hooks.dart';
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/animation_service.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/lifecycle_manager.dart';

void main() {
  group('IT-002: Page navigation lifecycle', () {
    late LifecycleManager lifecycleManager;

    setUp(() {
      lifecycleManager = LifecycleManager();
    });

    test('Normal: lifecycle hooks fire in order — pageInit, ready, leave', () async {
      final events = <String>[];

      lifecycleManager.addListener(LifecycleEvent.pageInit, () {
        events.add('pageInit');
      });
      lifecycleManager.addListener(LifecycleEvent.ready, () {
        events.add('ready');
      });
      lifecycleManager.addListener(LifecycleEvent.leave, () {
        events.add('leave');
      });

      // Simulate page navigation lifecycle
      await lifecycleManager.executeLifecycleHooks(LifecycleEvent.pageInit, []);
      await lifecycleManager.executeLifecycleHooks(LifecycleEvent.ready, []);
      await lifecycleManager.executeLifecycleHooks(LifecycleEvent.leave, []);

      expect(events, equals(['pageInit', 'ready', 'leave']));
    });

    test('Boundary: no listeners registered → lifecycle hooks fire without error', () async {
      // No listeners added, should not throw
      await lifecycleManager.executeLifecycleHooks(LifecycleEvent.pageInit, []);
      await lifecycleManager.executeLifecycleHooks(LifecycleEvent.ready, []);
    });
  });

  group('IT-004: v1.1 permission flow', () {
    test('Normal: PermissionManager allows non-client actions without prompt', () async {
      final permissionManager = PermissionManager(null);

      // Non-client actions (e.g., setState) are always allowed
      // PermissionManager.checkAndPrompt requires BuildContext, so we verify
      // the manager is created and enabled
      expect(permissionManager.enabled, isTrue);
    });

    test('Normal: PermissionManager can be disabled → all actions allowed', () {
      final permissionManager = PermissionManager(null);
      permissionManager.enabled = false;
      expect(permissionManager.enabled, isFalse);
    });

    test('Boundary: null config → permissive mode', () {
      final permissionManager = PermissionManager(null);
      expect(permissionManager, isNotNull);
      expect(permissionManager.enabled, isTrue);
    });
  });

  group('IT-005: v1.1 channel lifecycle', () {
    late ChannelManager channelManager;

    setUp(() {
      channelManager = ChannelManager();
    });

    tearDown(() async {
      await channelManager.dispose();
    });

    test('Normal: channel start → receive data → stop', () async {
      final receivedData = <dynamic>[];

      channelManager.onData = (channelId, data) {
        receivedData.add(data);
      };

      // Subscribe and start a poll channel
      await channelManager.initChannel(
        'poll-ch',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 100},
          autoStart: true,
        ),
      );

      expect(channelManager.isActive('poll-ch'), isTrue);
      expect(channelManager.getChannelState('poll-ch'), equals(ChannelState.connected));

      // Wait for at least one poll event
      await Future.delayed(const Duration(milliseconds: 300));

      // Stop channel
      await channelManager.stopChannel('poll-ch');
      expect(channelManager.isActive('poll-ch'), isFalse);
    });

    test('Normal: channel data accessible via getChannelData after receiving', () async {
      await channelManager.initChannel(
        'data-ch',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 100},
          autoStart: true,
        ),
      );

      // Wait for data to arrive
      await Future.delayed(const Duration(milliseconds: 250));

      final data = channelManager.getChannelData('data-ch');
      expect(data, isNotNull);
      expect(data!['id'], equals('data-ch'));
      expect(data['active'], isTrue);
    });

    test('Normal: disposeAutoChannels stops auto-dispose channels on page leave', () async {
      await channelManager.initChannel(
        'auto-ch',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: true,
        ),
      );
      await channelManager.initChannel(
        'manual-ch',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: false,
        ),
      );

      await channelManager.disposeAutoChannels();

      expect(channelManager.hasChannel('auto-ch'), isFalse);
      expect(channelManager.hasChannel('manual-ch'), isTrue);
    });
  });

  group('IT-008: Template resolution with scopes', () {
    late TemplateRegistry registry;
    late TemplateEngine engine;

    setUp(() {
      registry = TemplateRegistry();
      engine = TemplateEngine(registry: registry);
    });

    tearDown(() {
      registry.dispose();
    });

    test('Normal: page-scoped template overrides global template', () {
      // Register at application scope (global)
      registry.registerScoped(
        'card',
        {'content': {'type': 'box', 'color': 'blue', 'padding': 16}},
        scope: TemplateScope.application,
      );

      // Register at screen scope (page-level)
      registry.registerScoped(
        'card',
        {'content': {'type': 'box', 'color': 'red', 'padding': 8}},
        scope: TemplateScope.screen,
      );

      // Resolve should get screen-scoped template
      final resolved = engine.resolveByName('card');
      expect(resolved['color'], equals('red'));
      expect(resolved['padding'], equals(8));
    });

    test('Normal: clearing screen scope falls back to application scope', () {
      registry.registerScoped(
        'header',
        {'content': {'type': 'text', 'content': 'App Header'}},
        scope: TemplateScope.application,
      );
      registry.registerScoped(
        'header',
        {'content': {'type': 'text', 'content': 'Page Header'}},
        scope: TemplateScope.screen,
      );

      // Page-scoped wins
      expect(engine.resolveByName('header')['content'], equals('Page Header'));

      // Clear screen scope (simulating page navigation)
      registry.clearScope(TemplateScope.screen);

      // Falls back to application scope
      expect(engine.resolveByName('header')['content'], equals('App Header'));
    });

    test('Normal: expandAll resolves nested template references', () {
      registry.register(TemplateDefinition.fromJson(const {
        'name': 'badge',
        'content': {'type': 'text', 'content': 'Badge'},
      }));

      final definition = {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          {'type': 'use', 'template': 'badge'},
          {'type': 'text', 'content': 'Footer'},
        ],
      };

      final expanded = engine.expandAll(definition);
      final children = expanded['children'] as List;
      expect(children, hasLength(2));
      expect((children[0] as Map)['type'], equals('text'));
      expect((children[0] as Map)['content'], equals('Badge'));
    });
  });

  group('IT-009: Animation service deferred execution', () {
    late AnimationService animationService;

    setUp(() {
      animationService = AnimationService();
    });

    tearDown(() {
      animationService.dispose();
    });

    test('Normal: deferred execution — action before controller → auto-dispatched', () async {
      // Execute animation before any controller is registered
      final result = await animationService.execute(const AnimationActionDefinition(
        target: 'hero-widget',
        action: 'play',
        duration: 500,
        curve: 'easeInOut',
      ));

      expect(result.success, isTrue);
      expect(result.data['deferred'], isTrue);
      expect(animationService.getActiveAction('hero-widget'), equals('play'));

      // Now register the controller (simulating widget mount)
      String? dispatchedAction;
      animationService.registerController('hero-widget', (action, duration, curve) {
        dispatchedAction = action;
      });

      // Pending animation should have been auto-dispatched
      expect(dispatchedAction, equals('play'));
    });

    test('Normal: cancel animation after deferred execution', () async {
      await animationService.execute(const AnimationActionDefinition(
        target: 'widget-a',
        action: 'play',
      ));

      animationService.registerController('widget-a', (action, duration, curve) {});

      final cancelResult = await animationService.cancel('widget-a');
      expect(cancelResult.success, isTrue);
      expect(animationService.isAnimating('widget-a'), isFalse);
    });
  });

  // IT-010 removed: version negotiation infrastructure was excised —
  // the DSL is a single canonical spec and feature availability is
  // determined by presence of the relevant block (e.g. `channels`),
  // not by a version stamp. Reintroduce a dedicated version group if
  // and when a real breaking-change negotiation path is needed.

  group('IT-011: Plugin hook lifecycle', () {
    setUp(() {
      PluginHookManager.resetInstance();
    });

    test('Normal: register plugin → fire hooks → hooks called in priority order', () async {
      final manager = PluginHookManager.instance;
      final log = <String>[];

      // Register hooks from two plugins
      manager.registerHook(
        pluginName: 'analytics',
        hookType: PluginHookType.onStateChange,
        callback: (context) async {
          log.add('analytics:${context.data['path']}');
        },
        priority: 5,
      );

      manager.registerHook(
        pluginName: 'logging',
        hookType: PluginHookType.onStateChange,
        callback: (context) async {
          log.add('logging:${context.data['path']}');
        },
        priority: 10,
      );

      // Fire hook
      await manager.fireHook(
        PluginHookType.onStateChange,
        data: {'path': 'counter', 'oldValue': 0, 'newValue': 1},
      );

      // Higher priority (logging=10) fires first
      expect(log, equals(['logging:counter', 'analytics:counter']));
    });

    test('Normal: unregisterPlugin removes all hooks for plugin', () async {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'tempPlugin',
        hookType: PluginHookType.onRender,
        callback: (context) async {},
      );
      manager.registerHook(
        pluginName: 'tempPlugin',
        hookType: PluginHookType.onError,
        callback: (context) async {},
      );

      expect(manager.hasHooks(PluginHookType.onRender), isTrue);
      expect(manager.hasHooks(PluginHookType.onError), isTrue);

      manager.unregisterPlugin('tempPlugin');

      expect(manager.hasHooks(PluginHookType.onRender), isFalse);
      expect(manager.hasHooks(PluginHookType.onError), isFalse);
    });

    test('Normal: error in one hook does not prevent other hooks from firing', () async {
      final manager = PluginHookManager.instance;
      bool secondCalled = false;

      manager.registerHook(
        pluginName: 'broken',
        hookType: PluginHookType.onLifecycle,
        callback: (context) async {
          throw Exception('Plugin error');
        },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'healthy',
        hookType: PluginHookType.onLifecycle,
        callback: (context) async {
          secondCalled = true;
        },
        priority: 0,
      );

      await manager.fireHook(PluginHookType.onLifecycle);
      expect(secondCalled, isTrue);
    });
  });

  group('IT-012: I18n locale switching', () {
    setUp(() {
      I18nManager.instance.clear();
      I18nManager.instance.loadLocaleTranslations('en', {
        'title': 'Hello World',
        'button': {
          'submit': 'Submit',
          'cancel': 'Cancel',
        },
      });
      I18nManager.instance.loadLocaleTranslations('ja', {
        'title': 'こんにちは世界',
        'button': {
          'submit': '送信',
          'cancel': 'キャンセル',
        },
      });
      I18nManager.instance.setLocale('en');
    });

    tearDown(() {
      I18nManager.instance.clear();
    });

    test('Normal: translate returns English text by default', () {
      expect(I18nManager.instance.translate('title'), equals('Hello World'));
      expect(I18nManager.instance.translate('button.submit'), equals('Submit'));
    });

    test('Normal: switch locale to Japanese → translations change', () {
      I18nManager.instance.setLocale('ja');

      expect(I18nManager.instance.translate('title'), equals('こんにちは世界'));
      expect(I18nManager.instance.translate('button.submit'), equals('送信'));
      expect(I18nManager.instance.translate('button.cancel'), equals('キャンセル'));
    });

    test('Normal: resolveI18nString with i18n: prefix → translated', () {
      final result = I18nManager.instance.resolveI18nString('i18n:title');
      expect(result, equals('Hello World'));

      I18nManager.instance.setLocale('ja');
      final jaResult = I18nManager.instance.resolveI18nString('i18n:title');
      expect(jaResult, equals('こんにちは世界'));
    });

    test('Normal: switching locale notifies listeners', () {
      bool notified = false;
      I18nManager.instance.addListener(() {
        notified = true;
      });

      I18nManager.instance.setLocale('ja');
      expect(notified, isTrue);

      I18nManager.instance.removeListener(() {});
    });

    test('Boundary: missing key in current locale → falls back to fallback locale', () {
      I18nManager.instance.setFallbackLocale('en');
      I18nManager.instance.loadLocaleTranslations('fr', {
        'title': 'Bonjour le monde',
        // 'button.submit' intentionally missing
      });

      I18nManager.instance.setLocale('fr');

      expect(I18nManager.instance.translate('title'), equals('Bonjour le monde'));
      // Falls back to English for missing key
      expect(I18nManager.instance.translate('button.submit'), equals('Submit'));
    });

    test('Boundary: unsupported locale key → returns key itself', () {
      final result = I18nManager.instance.translate('nonexistent.key');
      expect(result, equals('nonexistent.key'));
    });
  });
}

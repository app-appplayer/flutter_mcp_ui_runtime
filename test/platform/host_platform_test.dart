// `HostPlatform` — the one place the runtime asks who it is running on.
//
// Before this, three separate ladders of `Platform.isAndroid` / `isIOS` / …
// answered the same question in three files, each behind its own `kIsWeb`
// guard. Two readings of one fact can disagree, none of them could be told
// otherwise by the embedder, and none could be exercised anywhere but on the
// one machine the test happened to run on.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/client_binding_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/system_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/platform/host_platform.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:device_info_plus_platform_interface/model/base_device_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(HostPlatform.clearOverride);

  group('what the host says it is', () {
    test('every declared platform maps to its category', () {
      const expected = <String, String>{
        'android': 'mobile',
        'ios': 'mobile',
        'macos': 'desktop',
        'windows': 'desktop',
        'linux': 'desktop',
        'web': 'web',
        'fuchsia': 'unknown',
      };

      expected.forEach((name, category) {
        HostPlatform.override(name: name);
        expect(HostPlatform.name, name);
        expect(HostPlatform.category, category,
            reason: 'the category is derived from the name rather than read '
                'again — two readings of one fact can disagree, and a '
                'document branching on both would see a mobile platform in a '
                'desktop category');
      });
    });

    test('isWeb follows the same one answer', () {
      HostPlatform.override(name: 'web');
      expect(HostPlatform.isWeb, isTrue);

      HostPlatform.override(name: 'linux');
      expect(HostPlatform.isWeb, isFalse);
    });

    test('clearing the override goes back to the real host', () {
      HostPlatform.override(name: 'android');
      expect(HostPlatform.name, 'android');

      HostPlatform.clearOverride();

      expect(HostPlatform.name, isNot('android'),
          reason: 'an override that outlives the caller would make every '
              'later reader believe a platform nobody is on');
      expect(const <String>{'macos', 'linux', 'windows'},
          contains(HostPlatform.name),
          reason: 'the suite runs on a desktop host');
      expect(HostPlatform.category, 'desktop');
    });

    test('the OS version can be stated too', () {
      HostPlatform.override(name: 'android', osVersion: 'Android 14');

      expect(HostPlatform.osVersion, 'Android 14');
    });
  });

  group('what reads it', () {
    RenderContext contextFor() {
      final stateManager = StateManager()..initialize(<String, dynamic>{});
      final bindingEngine = BindingEngine();
      final actionHandler = ActionHandler();
      return RenderContext(
        renderer: Renderer(
          widgetRegistry: WidgetRegistry(),
          bindingEngine: bindingEngine,
          actionHandler: actionHandler,
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
      );
    }

    // NOTE — `{{client.platform}}` answers the CATEGORY today
    // (`mobile`/`desktop`/`web`), while §8.5 defines it as one of
    // `macos, linux, windows, ios, android, web`. A document written against
    // the spec and branching on `== 'macos'` therefore never matches. The OS
    // name is reachable as `{{client.platform.os}}`, which the spec does not
    // mention. Pinned as it is rather than changed on the way past: flipping
    // it changes what every document already in the field reads. Recorded for
    // decision.
    // The resolver caches for a minute, so each reading gets its own.
    dynamic read(String binding) =>
        (ClientBindingResolver()..cacheEnabled = false).resolve(binding);

    test('`{{client.platform}}` answers the category, not the OS name', () {
      HostPlatform.override(name: 'android');
      expect(read('{{client.platform}}'), 'mobile');

      HostPlatform.override(name: 'windows');
      expect(read('{{client.platform}}'), 'desktop');
    });

    test('`{{client.platform.os}}` is the host name itself', () {
      for (final name in const ['android', 'ios', 'windows']) {
        HostPlatform.override(name: name);
        expect(read('{{client.platform.os}}'), name,
            reason: 'a document choosing a file path or a layout from the OS '
                'reads whatever the runtime believes; one source for it is '
                'the whole point');
      }
    });

    test('`{{client.platform.category}}` and `{{client.isWeb}}` agree with it',
        () {
      HostPlatform.override(name: 'web');
      expect(read('{{client.platform.category}}'), 'web');
      expect(read('{{client.isWeb}}'), isTrue);

      HostPlatform.override(name: 'macos');
      expect(read('{{client.platform.category}}'), 'desktop');
      expect(read('{{client.isWeb}}'), isFalse,
          reason: 'three readings of one fact used to sit in three files; '
              'they have to answer together or a document branching on two of '
              'them sees a contradiction');
    });

    test('`{{client.system.version}}` reports the stated OS version', () {
      HostPlatform.override(name: 'android', osVersion: 'Android 14');

      expect(read('{{client.system.version}}'), 'Android 14');
    });

    test('`client.getSystemInfo` reports the same platform', () async {
      HostPlatform.override(name: 'linux');

      final result = await SystemActionExecutor().getSystemInfo(
        <String, dynamic>{},
        contextFor(),
      );

      expect(result.success, isTrue);
      expect(result.data?['platform'], 'linux',
          reason: 'the action and the binding answer the same question; two '
              'sources for it is how they come to disagree');
      expect(result.data?['isWeb'], isFalse);
    });

    test('on a browser the action reports web and asks for no device info',
        () async {
      HostPlatform.override(name: 'web');

      final result = await SystemActionExecutor().getSystemInfo(
        <String, dynamic>{},
        contextFor(),
      );

      expect(result.data?['platform'], 'web');
      expect(result.data?['isWeb'], isTrue);
      expect(result.data?.containsKey('device'), isFalse,
          reason: 'a browser has no device to describe; asking the plugin for '
              'one there is what the `kIsWeb` guard at every call site was '
              'for');
    });

    test('only the named properties come back when the document asks for some',
        () async {
      HostPlatform.override(name: 'macos');

      final result = await SystemActionExecutor().getSystemInfo(
        <String, dynamic>{
          'properties': <dynamic>['platform', 'isWeb'],
        },
        contextFor(),
      );

      expect(result.data?.keys, containsAll(<String>['platform', 'isWeb']));
      expect(result.data?.containsKey('locale'), isFalse,
          reason: 'a document that asked for two fields and got twenty has to '
              'filter them itself, which is what the parameter is for');
    });
  });
  // The per-platform device fields. Until the host answer became something a
  // test could state, these five branches were reachable on exactly one
  // machine each — so the mapping from what the plugin returns to what a
  // document reads (`osVersion`, `model`, `device`) had never been checked on
  // any platform but the one the suite happens to run on.
  group('the device fields for each host', () {
    late DeviceInfoPlatform original;

    setUp(() => original = DeviceInfoPlatform.instance);
    tearDown(() => DeviceInfoPlatform.instance = original);

    void answerWith(Map<String, dynamic> data) {
      DeviceInfoPlatform.instance = _FakeDeviceInfo(BaseDeviceInfo(data));
    }

    Future<Map<String, dynamic>?> infoFor(String platform) async {
      HostPlatform.override(name: platform);
      final result = await SystemActionExecutor().getSystemInfo(
        <String, dynamic>{},
        _bareContext(),
      );
      return result.data;
    }

    test('android reports its model, maker and release', () async {
      answerWith(<String, dynamic>{
        ..._androidDefaults,
        'device': 'pixel',
        'model': 'Pixel 8',
        'manufacturer': 'Google',
        'version': <String, dynamic>{..._androidVersionDefaults, 'release': '14', 'sdkInt': 34},
      });

      final info = await infoFor('android');

      expect(info?['device'], 'pixel');
      expect(info?['model'], 'Pixel 8');
      expect(info?['manufacturer'], 'Google');
      expect(info?['osVersion'], 'Android 14',
          reason: 'the version a document shows in a support footer is built '
              'here; the raw release number alone does not say which OS');
      expect(info?['sdkInt'], 34);
    });

    test('ios reports its name, model and system version', () async {
      answerWith(<String, dynamic>{
        'name': 'Ada\'s iPhone',
        'systemName': 'iOS',
        'systemVersion': '17.4',
        'model': 'iPhone',
        'localizedModel': 'iPhone',
        'identifierForVendor': 'abc',
        'isPhysicalDevice': true,
        'utsname': <String, dynamic>{
          'sysname': 'Darwin',
          'nodename': 'iPhone',
          'release': '23.4.0',
          'version': 'x',
          'machine': 'iPhone16,1',
        },
      });

      final info = await infoFor('ios');

      expect(info?['device'], 'Ada\'s iPhone');
      expect(info?['model'], 'iPhone');
      expect(info?['osVersion'], 'iOS 17.4');
      expect(info?['isPhysicalDevice'], isTrue,
          reason: 'a document that behaves differently in a simulator reads '
              'this; defaulting it either way is a wrong answer half the time');
    });

    test('macos reports its computer name, model and release', () async {
      answerWith(<String, dynamic>{
        'computerName': 'Ada Mac',
        'hostName': 'ada.local',
        'arch': 'arm64',
        'model': 'Mac15,3',
        'kernelVersion': 'Darwin 23.4.0',
        'osRelease': '14.4',
        'majorVersion': 14,
        'minorVersion': 4,
        'patchVersion': 0,
        'activeCPUs': 8,
        'memorySize': 17179869184,
        'cpuFrequency': 0,
        'systemGUID': 'guid',
      });

      final info = await infoFor('macos');

      expect(info?['device'], 'Ada Mac');
      expect(info?['model'], 'Mac15,3');
      expect(info?['osVersion'], 'macOS 14.4');
      expect(info?['arch'], 'arm64',
          reason: 'a document offering an Apple-silicon-only download reads '
              'the architecture; guessing it offers the wrong binary');
    });

    test('linux reports its distribution name', () async {
      DeviceInfoPlatform.instance = _FakeDeviceInfo(LinuxDeviceInfo(
        name: 'Ubuntu',
        id: 'ubuntu',
        prettyName: 'Ubuntu 24.04 LTS',
        machineId: 'machine',
      ));

      final info = await infoFor('linux');

      expect(info?['device'], 'Ubuntu');
      expect(info?['osVersion'], 'Ubuntu 24.04 LTS',
          reason: 'the pretty name is the one a user recognises in a support '
              'footer; the bare id is not');
    });

    test('a plugin answering the wrong shape leaves the device fields out, '
        'and the call still succeeds', () async {
      answerWith(<String, dynamic>{'unexpected': true});

      final info = await infoFor('linux');

      expect(info?['platform'], 'linux',
          reason: 'the platform name does not come from the plugin, so it is '
              'still right');
      expect(info?.containsKey('device'), isFalse,
          reason: 'a device lookup that fails must not take the whole '
              'getSystemInfo down with it — the document still needs the '
              'locale and the platform');
    });
  });
}

/// A device-info plugin the test answers for.
class _FakeDeviceInfo extends DeviceInfoPlatform {
  _FakeDeviceInfo(this._info);

  final BaseDeviceInfo _info;

  @override
  Future<BaseDeviceInfo> deviceInfo() async => _info;
}

RenderContext _bareContext() {
  final stateManager = StateManager()..initialize(<String, dynamic>{});
  final bindingEngine = BindingEngine();
  final actionHandler = ActionHandler();
  return RenderContext(
    renderer: Renderer(
      widgetRegistry: WidgetRegistry(),
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    ),
    stateManager: stateManager,
    bindingEngine: bindingEngine,
    actionHandler: actionHandler,
    themeManager: ThemeManager.instance,
  );
}

/// Everything `AndroidDeviceInfo.fromMap` reads and this runtime does not.
const _androidDefaults = <String, dynamic>{
  'board': '',
  'bootloader': '',
  'brand': '',
  'display': '',
  'fingerprint': '',
  'hardware': '',
  'host': '',
  'id': '',
  'product': '',
  'tags': '',
  'type': '',
  'isPhysicalDevice': true,
  'serialNumber': '',
  'isLowRamDevice': false,
};

const _androidVersionDefaults = <String, dynamic>{
  'baseOS': '',
  'codename': '',
  'incremental': '',
  'previewSdkInt': 0,
  'securityPatch': '',
};

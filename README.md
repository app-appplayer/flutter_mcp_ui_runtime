# flutter_mcp_ui_runtime

Comprehensive runtime for building dynamic, reactive Flutter UIs from JSON specifications. Implements the **MCP UI DSL 1.4** specification with Material 3 theming, responsive form factors, lifecycle management, state handling, and MCP protocol integration.

## Features

- **Dynamic UI rendering** — 158 widgets across layout, display, input, list, navigation, scroll, animation, interaction, dialog and advanced categories.
- **One asset path** — every slot typed `AssetRef` (`image` · `icon` · `avatar` · `BackgroundImage` · `mediaPlayer` · …) resolves through a single resolver: `data:`, `assets/` and `http(s)` out of the box, and `bundle://`, `client://` or an origin-served `{uri, origin?}` once the host injects a reader. A runtime declares only the forms it was wired for.
- **Vector assets** — SVG payloads draw in every `AssetRef` slot, including `icon`, where a colour filter tints them the way it tints the named and codepoint forms. Same scheme dispatch as raster, on every platform the runtime ships to (web included). Adds `flutter_svg`.
- **Unresolvable assets stay off the screen** — an asset the runtime cannot reach takes the slot's declared `fallback` / `fallbackUrl` / `fallbackBehavior`, and the reason goes to the diagnostic channel. A box naming the runtime's limitation is not rendered in place of the picture (spec §6.12.4).
- **Material 3 theming** — `ThemeManager` + `McpUiThemeBuilder` map a strongly-typed `ThemeDefinition` (28-role color, 15-role typography, 7-family shape, 6-level elevation, density, surface containers) onto Flutter's `ThemeData`.
- **HCT seed palettes** — single seed color drives the full M3 light/dark palette.
- **Page-level theme overrides** — `applyOverride(Map)` deep-merges 14-domain JSON with a restore callback.
- **Responsive form factors** — `FormFactor` (compact / medium / expanded / large / embedded) with `FormFactorScope`, `ViewModeResolver` priority chain, and four scaled token sets (`AppSpacing`, `AppIconSizes`, `AppTypography`, `AppDensity`).
- **Auto-adaptive navigation** — drawer auto-swaps to modal drawer (compact) / NavigationRail (medium) / permanent drawer (expanded+).
- **Expression binding** — `{{theme.color.<slot>}}`, `{{theme.typography.<role>}}`, `{{theme.spacing.<token>}}`, `{{theme.shape.<family>}}`, `{{theme.elevation.<level>.shadow}}`, `{{theme.motion.duration.<key>}}` plus state and bundle bindings.
- **Action system** — state, tool, batch, conditional actions.
- **State management** — page-level + application-level with persistence via `SharedPreferences`.
- **MCP integration** — multiple-server orchestration, tool executor wiring, resource subscription with proper cleanup.
- **Editor inspection hook** — `MCPUIRuntime.withInspector(widgetWrapper:)` pairs each rendered widget with its source JSON node so visual editors can hit-test from the rendered tree back to the canonical document. The standard constructor is unaffected — no per-node overhead.

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

class App extends StatefulWidget {
  const App({super.key, required this.definition});

  final Map<String, dynamic> definition;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final MCPUIRuntime _runtime = MCPUIRuntime();
  late final Future<void> _ready = _runtime.initialize(widget.definition);

  @override
  void dispose() {
    _runtime.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        // `buildUI()` provides its own MaterialApp when the definition
        // declares navigation — it installs the navigator key, theme and
        // form-factor builder itself, so it is not wrapped in another.
        return _runtime.buildUI(
          onToolCall: (tool, params) {
            // dispatch to your MCP client
          },
        );
      },
    );
  }
}
```

## Build Note: Dynamic Icons

**Every release build of an app embedding this runtime needs
`--no-tree-shake-icons`, on every target — web included.**

```sh
flutter build web --no-tree-shake-icons
flutter build apk --no-tree-shake-icons        # same for appbundle, ipa, macos …
```

Without it the build **fails**, and the error names files inside this package
rather than the app:

```
Target web_release_bundle failed: Avoid non-constant invocations of IconData
  flutter_mcp_ui_runtime/lib/src/utils/icon_resolver.dart
  flutter_mcp_ui_runtime/lib/src/widgets/display/icon_factory.dart
```

That is not a defect to report — it is what the DSL asks for. A document names
its icon at render time (`"home"`, or `{codepoint: 0xe88a}` served by a host),
so the codepoint cannot be a compile-time constant and the icon tree-shaker
cannot know which glyphs survive. The flag tells it to keep them all.

`flutter test` and `flutter test --platform chrome` do not tree-shake, so a
suite passing says nothing about this — the failure appears only in a release
build.

## Support

- [Issue Tracker](https://github.com/app-appplayer/flutter_mcp_ui_runtime/issues)
- [Discussions](https://github.com/app-appplayer/flutter_mcp_ui_runtime/discussions)

## License

MIT — see [LICENSE](LICENSE).

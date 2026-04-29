# flutter_mcp_ui_runtime

Comprehensive runtime for building dynamic, reactive Flutter UIs from JSON specifications. Implements the **MCP UI DSL 1.3** specification with Material 3 theming, responsive form factors, lifecycle management, state handling, and MCP protocol integration.

## Features

- **Dynamic UI rendering** — 77+ widgets across layout, display, input, list, navigation, scroll, animation, interaction, dialog categories.
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
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MCPUIRenderer(
        definition: myUiDefinition,
        toolExecutors: {'incrementCounter': () { /* ... */ }},
      ),
    );
  }
}
```

## Build Note: Dynamic Icons

Apps using dynamic icon names must build with `--no-tree-shake-icons`:

```sh
flutter build apk --no-tree-shake-icons
```

## Support

- [Issue Tracker](https://github.com/app-appplayer/flutter_mcp_ui_runtime/issues)
- [Discussions](https://github.com/app-appplayer/flutter_mcp_ui_runtime/discussions)

## License

MIT — see [LICENSE](LICENSE).

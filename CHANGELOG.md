## [0.5.0] - 2026-05-03 - Spec ↔ implementation alignment (1.3.3)

- Channel callbacks: `onMessage` (canonical, `onData` retained as getter alias) + new `onConnect` / `onDisconnect` dispatch.
- `chart` adds donut / polar / bubble; `codeEditor` accepts 7 themes (vsLight/vsDark/monokai/solarizedLight/solarizedDark/github/dracula) + 14 languages.
- `lazy.trigger: visible` (spec rename from `viewport`); `manual` case recognised.
- `services.kind: polling` / `subscription` accepted (mapped to existing `periodic` / `continuous`).
- `template.styles` map field; `bottomBar` / `rail` navigation canonical (legacy `bottomNavigation` / `bottom` aliases retained).
- Bumps `flutter_mcp_ui_core` to `^0.4.0`.

### Fixed
- `ThemeManager.getColorValue(slot)` — falls back to the fromSeed-derived M3 28-role palette when the slot is absent from the bundle's raw `theme.color` map (spec §5.3 expects bundles to declare only `seed` plus a handful of overrides; the missing roles must derive). Previously the lookup only consulted `_themeData = definition.toJson()` (raw, no derive), so DSL bindings like `theme.color.surfaceContainerHigh` resolved to `null` for any bundle that omitted the role — even though `toFlutterTheme().colorScheme.surfaceContainerHigh` was filled correctly. The two paths now match. Light / dark schemes are cached; cache is invalidated on every `setTheme` / `setThemeDefinition` / `resetTheme` / `reset` / `applyOverride` restore. Semantic roles (`success` / `warning` / `info` and their `on*` variants) are not on Flutter's `ColorScheme`, so the fallback returns `null` for those — bundles must declare them explicitly.
- `box` (and the shared `BoxDecorationResolver`) — `decoration: {color: ...}` is no longer silently dropped when neither top-level `color` nor `backgroundColor` is supplied. The factory previously injected `color: null` into the flat property bag, and the resolver's flat-vs-nested override pass treated the `containsKey('color')` hit as an explicit erasure of the nested value. Now: (a) the factory only overlays `color` when the merged top-level value is non-null, and (b) the resolver ignores null entries during the override pass — they cannot shadow nested fields. Same null-tolerant treatment applies to `gradient` / `image` / `border` / `borderRadius` / `boxShadow` / `shape` / `backdropBlur`. Surface-toned boxes (e.g. `decoration: {color: "surfaceContainerHigh"}`) finally render against the M3 surface tonal scale rather than transparent.

## [0.4.4] - 2026-05-02 - M3 + Responsive consumption layer (bug fix)

0.3.0 announced "Material 3 + Responsive" but the runtime side was
never actually wired up. 0.4.4 delivers the consumption surface so
the previously advertised features finally work.

### Fixed
- M3 token shorthand on `text.variant`, `box.padding`, `card.shape`,
  `card.elevation`, `button.elevation`, `icon.size` / `sizeToken` —
  resolves through the corresponding `theme.<domain>.<token>`.
- `FormFactorScope` auto-wrap on the runtime root, so
  `AppSpacing.of(context)` / `AppTypography.of` / `AppIconSizes.of` /
  `AppDensity.of` actually track the form factor.
- Per-form-factor property override map (`{compact, medium, expanded,
  large, extraLarge, embedded, default}`) resolves on every property,
  per spec § 14.2.
- Linux: `event_listen_cb` / `event_cancel_cb` return type aligned
  with `FlMethodErrorResponse*` so the plugin compiles against the
  current `flutter_linux.h`.

### Notes
- Bumps `flutter_mcp_ui_core` to `^0.3.2` for the matching schema
  additions.

## [0.4.3] - 2026-05-01 - errorBoundary / errorRecovery onError spec violation fix

### Fixed
- `errorBoundary` (spec §2.13.11) — onError child context was registering `error` (string) instead of the canonical `event` variable. Now registers `event: {error, stack}` so `{{event.error}}` and `{{event.stack}}` resolve as the spec specifies.
- `errorRecovery` (spec §2.13.12) — same variable-name violation; now registers `event: {error, stack}`. Stack trace is captured (was previously lost).
- `errorBoundary` was re-firing `onError` on every rebuild while the boundary remained in the error state. The action now dispatches exactly once per captured exception (in the post-frame callback that flips `_hasError`).

## [0.4.2] - 2026-05-01 - Tool response spec violation fix (§3.10 + §4.4.2)

### Fixed
- `§3.10` auto-merge — `ToolActionExecutor` now calls `stateManager.mergeState(response)` when the tool response is a Map and `bindResult` is not specified, instead of leaving fold to host code. Top-level keys of the response land directly on page state.
- `§4.4.2` onSuccess/onError variable — child context now exposes the canonical `event` variable. `{{event.<key>}}` resolves to the response body inside `onSuccess`; inside `onError`, `event` is `{code, message, details}` per spec. Previously the runtime registered `response` / `error` (string), so the spec patterns silently failed.

### Migration
- DSL written against the previous (non-spec) `{{response.<key>}}` / `{{error.message}}` shapes must move to `{{event.<key>}}` to keep working.

## [0.4.1] - 2026-04-30 - Template auto-registration + theme system fixes + spec alignment

### Fixed
- `RuntimeEngine` now reads the `templates` block from the application / page definition during `initialize` and registers each entry into the `TemplateRegistry` (application scope for application roots, screen scope for standalone pages). Previously the block was silently ignored, so any `{ "type": "use", "template": "<name>" }` reference in the DSL failed to resolve and the widget went unrendered.
- `ThemeManager.flutterThemeMode` now honours `setHostBrightness` for `mode: 'system'` resolution: when the embedder injects a brightness override, it returns `ThemeMode.light` / `ThemeMode.dark` accordingly instead of always emitting `ThemeMode.system` (which Flutter resolves against OS brightness only). AppPlayer-class hosts are "the system" for embedded bundles, so launcher light/dark toggles now propagate into nested `MaterialApp` instances.
- `ThemeManager.toFlutterTheme(isDark: true)` no longer falls back to the active (light) `_definition` when the bundle declares no `dark` variant — it now returns `ThemeDefinition.defaultDark()` so the M3 default dark scheme is used. Previously bundles with an empty theme block could only render light, regardless of host brightness.
- **Template / `itemTemplate` instance state binding across close → reopen cycles.** The singleton `WidgetCache` was retaining widget instances whose event-handler closures captured the prior session's destroyed `RenderContext` (`StateManager`, `ActionHandler`). After a host-driven close → reopen, the rebuilt UI tree showed cached widgets whose `onTap` mutations targeted the dead engine, so visible state never updated even though buttons appeared responsive. Fix has three parts working together:
  - `Renderer._hasEventHandlers` now recurses through `child` / `children`, so an ancestor container holding event-bound descendants is also flagged non-cacheable. Previously a `linear` / `box` wrapping an `onTap` button could be cached even though its subtree's closures captured a stale context.
  - `'use'` is added to `nonCacheableTypes`. Each `use` site is an instance — its expansion MUST be a fresh widget subtree, not a shared cached widget across invocations or sessions.
  - `MCPUIRuntime.destroy()` now calls `WidgetCache.instance.clear()` to drop all cached entries from the dying session, so the next session starts with a clean cache and cannot inherit closures bound to a destroyed engine.
  - The same fix covers the `list.itemTemplate` (spec §9.6.1) instantiation path, since per-item expansions also produce fresh subtrees and the recursive event-handler check now catches buttons nested anywhere in the row template.

### Changed (breaking — pre-launch spec alignment)
- `ExtendedTemplateDefinition` widget tree wrapper field renamed `body` → `content` to align with MCP UI DSL 1.3 §9.2.2 (the canonical key for the template's widget tree). The use-site invocation key (`params:` on the `use` widget) is unchanged.
- `TemplateRegistry.isTemplateReference` now accepts only the canonical `type: "use"`. Legacy aliases (`type: "template"` / `type: "useTemplate"`) are removed in line with the spec's no-alias-accretion policy. Bundles using the legacy types must migrate to `type: "use"`.

## [0.4.0] - 2026-04-29 - Render inspector hook

- New `MCPUIRuntime.withInspector(...)` for editor tooling — pairs each rendered widget with its source JSON node. Standard constructor unchanged; no overhead when no inspector is supplied.

## [0.3.0] - 2026-04-28 - MCP UI DSL 1.3 (Material 3 + Responsive)

### Changed (breaking)
- **`ThemeManager` rewritten** on top of strongly-typed `ThemeDefinition` from `flutter_mcp_ui_core` — drops the 1.2-era 11-slot raw map and parallel default scheme.
- Theme bindings use the new path scheme (`theme.color.<slot>`, `theme.typography.<role>`, `theme.spacing.<token>`, `theme.shape.<family>`, `theme.elevation.<level>.shadow`, `theme.motion.duration.<key>`). Legacy `theme.colorScheme.*`, `theme.borderRadius.*`, `theme.spacing.medium`, `theme.elevation.small` are removed.
- `widget_factory` semantic color slots aligned to M3 28-role + semantic family (no `background` / `divider`).
- DSL version constant now sourced from `flutter_mcp_ui_core` `MCPUIDSLVersion` (runtime's own `DSLVersion` enum removed).
- License changed from Apache-2.0 to MIT.

### Added
- **`McpUiThemeBuilder`** — converts `ThemeDefinition` into Flutter `ThemeData` (`ColorScheme`, `TextTheme`, `VisualDensity`, `CardThemeData`, `DialogThemeData`).
- HCT-seed-derived default theme (`SeedPalette.lightFromSeed` / `darkFromSeed`).
- **Page-level theme override** — `applyOverride(Map)` deep-merges 14-domain JSON, returns restore callback (spec §5.7).
- **Responsive form factor scaffold** — `FormFactor` enum (compact / medium / expanded / large / embedded), `FormFactorScope`, `ViewModeResolver` priority chain.
- Four responsive token sets with `.of(context)` accessors — `AppSpacing`, `AppIconSizes`, `AppTypography`, `AppDensity`.
- **Auto-adaptive navigation** — drawer swaps to modal drawer (compact) / NavigationRail (medium) / permanent drawer (expanded+).
- New dependency: `mcp_bundle ^0.3.0`.

## 0.2.5

### Bug Fixes
- Fixed resource subscription cleanup on runtime destroy to properly unsubscribe from all active resources

## 0.2.4

## 0.2.3

### Documentation
- Added important build instructions for dynamic icons
- Documented the need for `--no-tree-shake-icons` flag when building apps with dynamic icons

## 0.2.2

### Bug Fixes
- Fixed navigation state persistence to properly save and restore tab/navigation positions
- Added SharedPreferences support to CacheManager for actual disk persistence
- Fixed setState during build error in ApplicationShell navigation initialization

## 0.2.1

### Bug Fixes
- Fixed state initialization issue where page states were not properly loaded
- Unified state management by removing duplicate StateService and using StateManager directly
- Fixed page state initialization in routing system

## 0.2.0

### Refactoring
- Major internal refactoring for improved maintainability
- Enhanced code organization and structure
- Improved type safety and validation
- Better separation of concerns

## 0.1.0

### Initial Release

- Comprehensive runtime for building dynamic, reactive UIs through JSON specifications
- Support for 77+ Flutter widgets across 9 categories
- Built-in state management with automatic UI updates
- Expression binding system with support for nested paths and transforms
- Action system (state, tool, batch, conditional, navigation)
- Multiple instance support for different MCP servers
- Tool executor injection for external API integration
- Custom widget registration support
- Custom transform registration
- Theme management with light/dark mode support
- Navigation and routing system
- Dialog and notification services
- Background service management
- Lifecycle management
- Service registry pattern
- Based on MCP UI DSL v1.0 specification
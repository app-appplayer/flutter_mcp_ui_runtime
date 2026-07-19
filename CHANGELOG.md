## [0.5.2] - 2026-07-19 — `client.mcpStream` channel type: MCP-server-pushed live streams (spec 1.3 §8.6.2)

### Added
- **`client.mcpStream` channel type** — the first channel that carries an MCP-server-**pushed** live stream. The prior five types cannot: `client.poll` re-invokes a tool on an interval (pull) and `client.websocket` is a raw socket outside MCP. `client.mcpStream` subscribes a host-registered stream source identified by its `uri` scheme and forwards each server push through the normal channel machinery (lifecycle, backpressure, `onMessage`/`onError`/`onConnect`/`onDisconnect`). `McpStreamChannel` (`src/channels/channel_types/mcp_stream_channel.dart`) implements it; `ChannelManager._createChannel` gains the case with a **late-bound** resolver (the channel is created at page init but the host registers its source after runtime init, so resolution is deferred to `start()`).
- **`MCPUIRuntime.registerStreamSource(scheme, open)`** — the host seam. A host wires a real transport per uri scheme (e.g. `ble` → a BLE scan hub) while the runtime stays transport-agnostic; all schemes share one resolver on the channel manager. Mirrors `registerToolExecutor`.

### Changed
- `flutter_mcp_ui_core` floor raised `^0.4.1 → ^0.4.2` (the regenerated page schema listing `client.mcpStream`); `mcp_bundle` floor raised `^0.4.0 → ^0.4.8` (floors-at-latest on cut). Consumers should bump to `^0.5.2`.

### Notes
- Purely additive and version-neutral: a runtime predating the type hits `_createChannel`'s `default` branch and ignores the unknown type (graceful coexistence). The `major.minor` DSL-version gate (`MCPUIDSLVersion`) is unchanged — `since v1.3`.

## [0.5.1] - 2026-05-23 — spec compliance Round 2 + mcp_bundle 0.4.0 cascade

### Changed (cascade)
- `mcp_bundle` caret bumped from `^0.3.0` to `^0.4.0`. The downstream `UiSection.pages` field switched to `Map<String, PageDefinition>`; this runtime's `bundle/bundle_page_adapter.dart` now iterates `uiSection.pages.values` so bundle activation still walks every page. Consumers should bump to `^0.5.1`.
- `flutter_mcp_ui_core` caret bumped to `^0.4.1` (mcp_bundle cascade).

### Added
- MCP wire shape unwrap — tool responses shaped as `{content:[{type:'text', text:S}], isError:bool}` now unwrap and JSON parse `S` before auto-merge (spec §3.10).
- `StateChangeEvent.source` canonical enum (`action` / `tool` / `subscription` / `system`) per spec §3.11. `mergeState` defaults to `'tool'`, `StateActionExecutor` to `'action'`, resource notification to `'subscription'`, `updateAll` to `'system'`.
- `RenderContext.onResourceRead` / `onResourceList` — separate host callbacks for spec §4.5 `read` / `list` sub-actions (fallback to `onResourceSubscribe` for backward compat).
- `onSubscriptionError` callback — spec §4.5 named field, dispatched when host subscribe handler throws. `event.{uri, binding, message}` child context.
- Non-Map response `event.value` wrap — spec §4.4.2: list / scalar / null tool responses expose `event.value = <response>` (with other `event.*` keys null).
- Common `click` field auto-wrap (spec 1.3.4 §2.2) — `WidgetFactory.applyCommonWrappers` now wraps any widget carrying a `click: Action` property in a `GestureDetector` and dispatches the action through `RenderContext.actionHandler` on tap. Universal across all 97 factories that call `applyCommonWrappers`; pure layout / decoration widgets (`box`, `card`, `linear`, `stack`, ...) become tappable without nesting a `gestureDetector` wrapper. `click` is resolved through the binding engine, so action maps may be supplied inline or via `{{...}}` binding. Click is applied BEFORE the enabled-state wrap so `enabled: false` (IgnorePointer) correctly suppresses the gesture surface. Widget-local activation slots (`button.onTap`, `iconButton.onTap`, `richText.spans[].onTap`, ...) remain canonical for those widgets and are unaffected.
- 26 new regression cases under `test/spec_compliance/runtime_spec_fix_2026_05_14_test.dart` locking the above.
- 6 new regression cases under `test/renderer/widget_factory_test.dart` for the common `click` field: GestureDetector wrap shape, end-to-end tap → action dispatch, tooltip + click coexistence, backward-compat no-click pass-through, non-Map click ignore, and `enabled:false` suppression via IgnorePointer.

### Deprecated
- Envelope `{success, result, message}` auto-unwrap — slated for removal in 0.6.0. Warning logged once per process.
- `tools.<tool>.result` namespaced mirror — slated for removal in 0.6.0. Warning logged once per process.

### Changed
- `runtime_engine.handleResourceNotification` / `handleMCPNotification` no longer apply `content[binding]` heuristic — raw content stored at binding per spec §4.5.
- Lifecycle `_renderContext` null short-circuit replaced with explicit error log.

### Fixed
- Tool responses arriving in MCP wire shape were merged as `content` / `isError` literal keys instead of unwrapped — now spec §3.10 compliant.
- `TemplateParamDefinition.validate` now skips declared-type and enum checks when the supplied argument is a binding expression (`"{{...}}"`). Mirrors the same fix in `flutter_mcp_ui_core`'s `TemplateDefinition.validate`; covers the extended-template (`resolveExtended`) path. Previously a template param declared `type: boolean` rejected every expression-bound argument (always a String at validate time), causing `use` invocations to surface the `Template not found:` placeholder. Spec §9.3.1 mandates only required / default / enum / validator and expressions resolve at runtime so cannot be compared against the enum list here either. Non-expression arguments still take the type / enum path unchanged. Regression: full templates test suite 88/88.
- `TemplateRegistry._substituteValue` now type-preserves whole-value placeholders. A param value shaped as a single `"{{name}}"` (with no surrounding literal text) was previously stringified by `_substituteString` via `value?.toString()` — a List param landed in the expanded template body as `"[a, b]"`, a Map as `"{x: 1}"`, an action Map (`{type:"tool",...}`) as `"{type: tool, ...}"`. Downstream factories receiving those props could no longer cast back to `List` / `Map<String, dynamic>?` (observed runtime: `'String' is not a subtype of type 'Map<String, dynamic>?'` from `inkWell.onTap` when a `template params.onActivate` action Map was forwarded into a nested `use`). The substitution now short-circuits whole-value placeholders to the raw param value; partial placeholders (`"Hello {{name}}"`) still take the string path unchanged.
- `ListViewWidgetFactory._ensureStableConstraints` is now orientation-aware. The defensive guard that wraps the ListView in a `SizedBox` when the parent supplies an unbounded constraint previously only checked `hasBoundedHeight`, so a `list` with `orientation: 'horizontal'` mounted inside a `Row` with a `Spacer` / `Expanded` sibling threw `Horizontal viewport was given unbounded width` at layout time (followed by a cascade of `RenderBox was not laid out` exceptions). The guard now branches on `scrollDirection`: horizontal lists check `hasBoundedWidth` and fall back to `SizedBox(width: MediaQuery.size.width)`; vertical lists keep the existing `hasBoundedHeight` / `SizedBox(height: ...)` path. Author intent is unchanged — explicit `shrinkWrap: true` or a parent-supplied size still short-circuits the guard.
- `text` widget pins `theme.color.onSurface` when `style.color` is unspecified. Spec §5.4.2 deliberately omits a `color` field on typography roles (Material 3 separates typography from colour), so `variant`-only / no-`style.color` text returned `TextStyle(color: null)` and Flutter fell through to the ambient `DefaultTextStyle.of(context).color` — which inherits from an ancestor `Theme` whose brightness can briefly diverge from the ThemeManager's effective mode during host tab transitions (an AppRendererScreen remount sees a stale `MediaQuery` / `Theme(brightness:)` frame before the host wrap re-applies its override). Visible in dark mode only — both ambient branches yield near-black under light, so the divergence is invisible there; in dark the same race surfaced as black-on-dark text frames after tab cycling. The factory now resolves `theme.color.onSurface` (the M3 canonical text colour) through ThemeManager at build time, breaking the ambient dependency. Author-supplied `style.color` still wins via the existing `merge` path. Regression: 2 new widget cases in `test/runtime/text_color_pin_test.dart` (onSurface pinned despite light-Theme ancestor / inline style.color overrides the pin).
- `ThemeManager.flutterThemeMode` now honours `_hostBrightnessOverride` unconditionally (in lockstep with `_resolveEffectiveMode`). Previously the override only applied when the bundle declared `mode: 'system'`, so a bundle with `mode: 'dark'` would resolve `theme.color.onSurface` to the host-pinned brightness via `getColorValue` while `MaterialApp.themeMode` still picked dark — the colour-token path and the ambient `ColorScheme` came from different brightnesses, producing the "ambient onSurface flips between frames" race the tab-cycle text fix above is the second half of. Regression: 5 new cases in `test/runtime/text_color_pin_test.dart::flutterThemeMode honours host override unconditionally`. Test `theme/theme_manager_test.dart::TC-TH-03 flutterThemeMode ignores host brightness ...` was inverted to lock the new contract (renamed to `... honours host brightness ...`) — policy change 2026-05-21, AppPlayer-class hosts are themselves "the system" for embedded bundles.
- `ThemeManager._resolveEffectiveMode` now treats a non-null `_hostBrightnessOverride` as the unconditional winner — previously the override only applied when `_themeMode == 'system'`, so a bundle that hard-declared `theme.mode: 'dark'` ignored the host's light/dark toggle entirely. Worse, the toggle's apparent effect depended on race-timing between `setTheme(appDef.theme)` (driven by the bundle's manifest at mount) and `setHostBrightness(...)` (driven by the host's chrome preview-mode pin) — whichever landed last won, producing an intermittent "text widget stays dark / surrounding chrome flips light" leak in `tools/builder/vibe_studio/vibe_studio_workspace`. `setHostBrightness` also now notifies unconditionally (the previous `if (_themeMode == 'system') notifyListeners()` guard would swallow the brightness change when a bundle declared an explicit mode). AppPlayer-class hosts are themselves "the system" for embedded bundles — when the host pins brightness, the bundle MUST follow. The identical-override early-return guard (`_hostBrightnessOverride == brightness`) is preserved, so no spurious rebuild. Regression: 6 new cases in `test/runtime/theme_host_override_priority_test.dart` (light flips dark bundle / dark flips light bundle / clear restores declared / always-notify / identical no-op / fingerprint changes for renderer cache invalidation).
- `RuntimeEngine.initialize` now forwards `ThemeManager` mutations to engine listeners. `setTheme` / `setThemeDefinition` / `setThemeMode` / `setHostBrightness` / `applyOverride` calls already invoked `ThemeManager.notifyListeners()` (six call sites), but the engine never `addListener`ed on `_themeManager`, so the notification stopped at the manager and widgets never rebuilt on a theme mutation. Hosts worked around this by bridging through `_stateManager` as a noop forward (sentinel: `tools/builder/vibe_studio/.../dsl_workspace_view.dart`). Spec `mcp_ui_dsl/spec/1.3/05_Theme.md` §L56 ("theme.mode … changes trigger theme recomputation and re-render") makes this re-render obligatory; the engine now satisfies it natively. The listener tear-off (`_themeListener = notifyListeners`) is held on the engine and detached in `destroy()` — ThemeManager is process-singleton, so an unreleased listener would outlive a destroyed engine and fire `notifyListeners` on a disposed receiver. Multi-host theme isolation (per-runtime ThemeManager) is unrelated to this fix and remains a separate refactor track. Regression: 3 new cases in `test/runtime/theme_forward_test.dart` (theme mutation forwards / destroy detaches cleanly / host bridge workaround is no longer necessary).

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
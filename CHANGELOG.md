
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
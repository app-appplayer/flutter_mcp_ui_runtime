
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
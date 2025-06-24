library flutter_mcp_ui_runtime;

// Core exports
export 'src/mcp_ui_runtime.dart' show MCPUIRuntime, MCPUIRuntimeHelper;
export 'src/renderer/render_context.dart';
export 'src/renderer/renderer.dart';
export 'src/runtime/widget_registry.dart';

// Model exports
export 'src/models/ui_definition.dart' hide BackgroundServiceType;

// Routing exports
export 'src/routing/route_manager.dart';
export 'src/routing/page_state_scope.dart';

// Navigation exports
export 'src/navigation/navigation_builder.dart';

// Runtime exports
export 'src/runtime/runtime_engine.dart';
export 'src/runtime/lifecycle_manager.dart';
export 'src/runtime/service_registry.dart' hide ServiceStatus;
export 'src/runtime/background_service_manager.dart';
export 'src/runtime/conformance_checker.dart';

// Service exports
export 'src/services/state_service.dart';
export 'src/services/navigation_service.dart';
export 'src/services/dialog_service.dart';
export 'src/services/notification_service.dart';

// State management exports
export 'src/state/state_manager.dart' show StateManager;
export 'src/state/state_watcher.dart';
export 'src/state/computed_property.dart';

// Action exports
export 'src/actions/action_handler.dart' show ActionHandler, NavigationActionExecutor;

// Notification exports
export 'src/notifications/notification_types.dart';
export 'src/notifications/notification_manager.dart';

// Widget factory exports
export 'src/widgets/widget_factory.dart';

// Utility exports
export 'src/utils/json_path.dart';
export 'src/utils/mcp_logger.dart';

// I18n exports
export 'src/i18n/i18n_manager.dart';
export 'src/i18n/i18n_loader.dart';

// Background service exports (using the runtime version)

// Virtualization exports
export 'src/widgets/virtualized/virtualized_list.dart';

// Debounce/Throttle exports
export 'src/utils/debounce.dart';

// Dependency injection exports
export 'src/core/service_locator.dart';

// Plugin system exports
export 'src/plugins/plugin_system.dart';

// Error boundary exports
export 'src/core/error_boundary.dart';

// Validation exports
export 'src/validation/validation_engine.dart' hide ValidationResult;
export 'src/validation/custom_validator.dart';

// Accessibility exports
export 'src/accessibility/focus_manager.dart';
export 'src/accessibility/live_regions.dart';
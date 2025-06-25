import 'package:flutter/material.dart';
import '../models/ui_definition.dart';
import '../runtime/runtime_engine.dart';
import '../runtime/lifecycle_manager.dart';
import '../renderer/render_context.dart';

/// Provides a page-specific state scope for multi-page applications
class PageStateScope extends InheritedNotifier<PageStateNotifier> {
  final PageDefinition pageDefinition;
  final String routePath;
  final RuntimeEngine runtimeEngine;

  PageStateScope({
    super.key,
    required this.pageDefinition,
    required this.routePath,
    required this.runtimeEngine,
    required super.child,
  }) : super(
          notifier: PageStateNotifier(pageDefinition.initialState ?? {}),
        );

  /// Get the page state map
  Map<String, dynamic> get pageState => notifier!.state;

  static PageStateScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PageStateScope>();
  }
}

/// Notifier for page state changes
class PageStateNotifier extends ChangeNotifier {
  final Map<String, dynamic> _state;

  PageStateNotifier(Map<String, dynamic> initialState)
      : _state = Map<String, dynamic>.from(initialState);

  Map<String, dynamic> get state => _state;

  void updateState(String key, dynamic value) {
    _state[key] = value;
    notifyListeners();
  }

  void updateAll(Map<String, dynamic> updates) {
    _state.addAll(updates);
    notifyListeners();
  }
}

/// Widget that renders a single page
class MCPPageWidget extends StatefulWidget {
  final PageDefinition pageDefinition;
  final RuntimeEngine runtimeEngine;

  const MCPPageWidget({
    super.key,
    required this.pageDefinition,
    required this.runtimeEngine,
  });

  @override
  State<MCPPageWidget> createState() => _MCPPageWidgetState();
}

class _MCPPageWidgetState extends State<MCPPageWidget> {
  @override
  void initState() {
    super.initState();
    // Defer initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePage();
    });
  }

  void _initializePage() {
    // Initialize page state in StateManager only for new values
    if (widget.pageDefinition.initialState != null) {
      // Only set values that don't already exist in global state
      widget.pageDefinition.initialState!.forEach((key, value) {
        if (widget.runtimeEngine.stateManager.get(key) == null) {
          widget.runtimeEngine.stateManager.set(key, value);
        }
      });
    }

    // Execute page onMount lifecycle
    final lifecycle = widget.pageDefinition.lifecycleDefinition;
    if (lifecycle?.onMount != null) {
      widget.runtimeEngine.lifecycle.executeLifecycleHooks(
        LifecycleEvent.mount,
        lifecycle!.onMount!,
      );
    }
  }

  @override
  void dispose() {
    // Execute page onUnmount lifecycle
    final lifecycle = widget.pageDefinition.lifecycleDefinition;
    if (lifecycle?.onUnmount != null) {
      widget.runtimeEngine.lifecycle.executeLifecycleHooks(
        LifecycleEvent.unmount,
        lifecycle!.onUnmount!,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create render context with BuildContext for state resolution
    final renderContext = RenderContext(
      renderer: widget.runtimeEngine.renderer,
      stateManager: widget.runtimeEngine.stateManager,
      bindingEngine: widget.runtimeEngine.bindingEngine,
      actionHandler: widget.runtimeEngine.actionHandler,
      themeManager: widget.runtimeEngine.themeManager,
      buildContext: context,
      engine: widget.runtimeEngine,
    );

    // Build the page content using the renderer
    return widget.runtimeEngine.renderer.renderWidget(
      widget.pageDefinition.content,
      renderContext,
    );
  }
}

/// Widget that provides page state scope wrapper
class MCPPageScopeWrapper extends StatelessWidget {
  final PageDefinition pageDefinition;
  final String routePath;
  final RuntimeEngine runtimeEngine;
  final Widget child;

  const MCPPageScopeWrapper({
    super.key,
    required this.pageDefinition,
    required this.routePath,
    required this.runtimeEngine,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PageStateScope(
      pageDefinition: pageDefinition,
      routePath: routePath,
      runtimeEngine: runtimeEngine,
      child: child,
    );
  }
}

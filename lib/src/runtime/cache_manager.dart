import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Cache manager for MCP UI Runtime
class CacheManager {
  CacheManager({
    this.enableDebugMode = kDebugMode,
  });

  final bool enableDebugMode;
  
  // In-memory cache for now, can be extended to use persistent storage
  final Map<String, CachedApp> _appCache = {};
  final Map<String, Map<String, dynamic>> _stateCache = {};
  final Map<String, Map<String, dynamic>> _resourceCache = {};

  /// Cache policy configuration
  CachePolicy _defaultPolicy = const CachePolicy();

  /// Gets the default cache policy
  CachePolicy get defaultPolicy => _defaultPolicy;

  /// Sets the default cache policy
  set defaultPolicy(CachePolicy policy) {
    _defaultPolicy = policy;
    if (enableDebugMode) {
      debugPrint('CacheManager: Default policy updated');
    }
  }

  /// Caches an app definition
  Future<void> cacheApp(CachedApp app) async {
    final key = '${app.domain}:${app.id}';
    _appCache[key] = app;
    
    if (enableDebugMode) {
      debugPrint('CacheManager: Cached app $key v${app.version}');
    }
  }

  /// Gets a cached app
  CachedApp? getCachedApp(String domain, String id) {
    final key = '$domain:$id';
    final app = _appCache[key];
    
    if (app != null && _isAppValid(app)) {
      if (enableDebugMode) {
        debugPrint('CacheManager: Cache hit for app $key');
      }
      return app;
    }
    
    if (enableDebugMode) {
      debugPrint('CacheManager: Cache miss for app $key');
    }
    return null;
  }

  /// Checks if a newer version is available
  bool isUpdateAvailable(String domain, String id, String currentVersion) {
    final key = '$domain:$id';
    final cached = _appCache[key];
    
    if (cached == null) return false;
    
    return _compareVersions(cached.version, currentVersion) > 0;
  }

  /// Caches app state
  Future<void> cacheState(String appKey, Map<String, dynamic> state) async {
    _stateCache[appKey] = Map<String, dynamic>.from(state);
    
    if (enableDebugMode) {
      debugPrint('CacheManager: Cached state for $appKey');
    }
    
    // TODO: Persist to local storage
  }

  /// Gets cached state
  Map<String, dynamic>? getCachedState(String appKey) {
    return _stateCache[appKey];
  }

  /// Caches a resource (e.g., downloaded data)
  Future<void> cacheResource(String key, Map<String, dynamic> data) async {
    _resourceCache[key] = Map<String, dynamic>.from(data);
    
    if (enableDebugMode) {
      debugPrint('CacheManager: Cached resource $key');
    }
  }

  /// Gets a cached resource
  Map<String, dynamic>? getCachedResource(String key) {
    return _resourceCache[key];
  }

  /// Clears all caches
  Future<void> clearAll() async {
    _appCache.clear();
    _stateCache.clear();
    _resourceCache.clear();
    
    if (enableDebugMode) {
      debugPrint('CacheManager: Cleared all caches');
    }
  }

  /// Clears app cache
  Future<void> clearApp(String domain, String id) async {
    final key = '$domain:$id';
    _appCache.remove(key);
    _stateCache.remove(key);
    
    if (enableDebugMode) {
      debugPrint('CacheManager: Cleared cache for app $key');
    }
  }

  /// Gets cache statistics
  CacheStats getStats() {
    return CacheStats(
      appCount: _appCache.length,
      stateCount: _stateCache.length,
      resourceCount: _resourceCache.length,
      totalSize: _calculateCacheSize(),
    );
  }

  /// Checks if app is still valid based on cache policy
  bool _isAppValid(CachedApp app) {
    final policy = app.cachePolicy ?? _defaultPolicy;
    
    if (!policy.enabled) return false;
    
    final now = DateTime.now();
    final age = now.difference(app.cachedAt);
    
    // Check max age
    if (policy.maxAge != null && age > policy.maxAge!) {
      return false;
    }
    
    // Check expiry time
    if (app.expiresAt != null && now.isAfter(app.expiresAt!)) {
      return false;
    }
    
    return true;
  }

  /// Compares version strings (simple semantic versioning)
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.tryParse).toList();
    final parts2 = v2.split('.').map(int.tryParse).toList();
    
    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? (parts1[i] ?? 0) : 0;
      final p2 = i < parts2.length ? (parts2[i] ?? 0) : 0;
      
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    
    return 0;
  }

  /// Calculates total cache size (simplified)
  int _calculateCacheSize() {
    int size = 0;
    
    // Estimate size of app definitions
    for (final app in _appCache.values) {
      size += jsonEncode(app.definition).length;
    }
    
    // Estimate size of states
    for (final state in _stateCache.values) {
      size += jsonEncode(state).length;
    }
    
    // Estimate size of resources
    for (final resource in _resourceCache.values) {
      size += jsonEncode(resource).length;
    }
    
    return size;
  }
}

/// Represents a cached app
class CachedApp {
  const CachedApp({
    required this.id,
    required this.domain,
    required this.version,
    required this.definition,
    required this.cachedAt,
    this.expiresAt,
    this.cachePolicy,
    this.checksum,
  });

  final String id;
  final String domain;
  final String version;
  final Map<String, dynamic> definition;
  final DateTime cachedAt;
  final DateTime? expiresAt;
  final CachePolicy? cachePolicy;
  final String? checksum;

  /// Creates a cached app from runtime definition
  factory CachedApp.fromDefinition(Map<String, dynamic> definition) {
    final runtime = definition['mcpRuntime'];
    if (runtime == null || runtime is! Map) {
      return CachedApp(
        id: 'unknown',
        domain: 'unknown',
        version: '1.0.0',
        definition: definition,
        cachedAt: DateTime.now(),
      );
    }
    
    final runtimeConfig = runtime['runtime'];
    final config = runtimeConfig is Map ? runtimeConfig : <String, dynamic>{};
    
    return CachedApp(
      id: config['id']?.toString() ?? 'unknown',
      domain: config['domain']?.toString() ?? 'unknown',
      version: config['version']?.toString() ?? '1.0.0',
      definition: definition,
      cachedAt: DateTime.now(),
      cachePolicy: config['cachePolicy'] is Map
          ? CachePolicy.fromJson(Map<String, dynamic>.from(config['cachePolicy'] as Map))
          : null,
    );
  }
}

/// Cache policy configuration
class CachePolicy {
  const CachePolicy({
    this.enabled = true,
    this.maxAge,
    this.staleWhileRevalidate = false,
    this.cacheState = true,
    this.cacheResources = true,
    this.offlineMode = OfflineMode.partial,
  });

  final bool enabled;
  final Duration? maxAge;
  final bool staleWhileRevalidate;
  final bool cacheState;
  final bool cacheResources;
  final OfflineMode offlineMode;

  factory CachePolicy.fromJson(Map<String, dynamic> json) {
    return CachePolicy(
      enabled: json['enabled'] as bool? ?? true,
      maxAge: json['maxAge'] != null
          ? Duration(seconds: json['maxAge'] as int)
          : null,
      staleWhileRevalidate: json['staleWhileRevalidate'] as bool? ?? false,
      cacheState: json['cacheState'] as bool? ?? true,
      cacheResources: json['cacheResources'] as bool? ?? true,
      offlineMode: _parseOfflineMode(json['offlineMode'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'maxAge': maxAge?.inSeconds,
      'staleWhileRevalidate': staleWhileRevalidate,
      'cacheState': cacheState,
      'cacheResources': cacheResources,
      'offlineMode': offlineMode.name,
    };
  }

  static OfflineMode _parseOfflineMode(String? mode) {
    switch (mode) {
      case 'full':
        return OfflineMode.full;
      case 'partial':
        return OfflineMode.partial;
      case 'disabled':
        return OfflineMode.disabled;
      default:
        return OfflineMode.partial;
    }
  }
}

/// Offline mode options
enum OfflineMode {
  /// Full offline support - all features work offline
  full,
  
  /// Partial offline support - UI and cached data work, but no tools/streaming
  partial,
  
  /// No offline support
  disabled,
}

/// Cache statistics
class CacheStats {
  const CacheStats({
    required this.appCount,
    required this.stateCount,
    required this.resourceCount,
    required this.totalSize,
  });

  final int appCount;
  final int stateCount;
  final int resourceCount;
  final int totalSize;

  @override
  String toString() {
    return 'CacheStats(apps: $appCount, states: $stateCount, resources: $resourceCount, size: ${(totalSize / 1024).toStringAsFixed(2)}KB)';
  }
}

/// Update policy for checking app updates
class UpdatePolicy {
  const UpdatePolicy({
    this.checkOnStartup = true,
    this.checkInterval = const Duration(hours: 24),
    this.autoUpdate = false,
    this.requireRestart = true,
  });

  final bool checkOnStartup;
  final Duration checkInterval;
  final bool autoUpdate;
  final bool requireRestart;

  factory UpdatePolicy.fromJson(Map<String, dynamic> json) {
    return UpdatePolicy(
      checkOnStartup: json['checkOnStartup'] as bool? ?? true,
      checkInterval: Duration(seconds: json['checkInterval'] as int? ?? 86400),
      autoUpdate: json['autoUpdate'] as bool? ?? false,
      requireRestart: json['requireRestart'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkOnStartup': checkOnStartup,
      'checkInterval': checkInterval.inSeconds,
      'autoUpdate': autoUpdate,
      'requireRestart': requireRestart,
    };
  }
}
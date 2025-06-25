import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/mcp_logger.dart';

/// Manager for internationalization support according to MCP UI DSL v1.0
class I18nManager extends ChangeNotifier {
  static I18nManager? _instance;
  static I18nManager get instance => _instance ??= I18nManager._();

  I18nManager._();

  // Current locale
  String _currentLocale = 'en';
  String get currentLocale => _currentLocale;

  // Translations storage - nested structure for dot notation support
  final Map<String, Map<String, dynamic>> _translations = {};

  // Fallback locale
  String _fallbackLocale = 'en';
  String get fallbackLocale => _fallbackLocale;

  final MCPLogger _logger = MCPLogger('I18nManager');

  /// Set the current locale
  void setLocale(String locale) {
    _currentLocale = locale;
    _logger.debug('Locale changed to: $locale');
    notifyListeners();
  }

  /// Set the fallback locale
  void setFallbackLocale(String locale) {
    _fallbackLocale = locale;
    _logger.debug('Fallback locale set to: $locale');
  }

  /// Load translations from configuration
  Future<void> loadTranslations(Map<String, dynamic> i18nConfig) async {
    _fallbackLocale = i18nConfig['fallbackLocale'] ?? 'en';
    final translations = i18nConfig['translations'] as Map<String, dynamic>?;

    if (translations != null) {
      _translations.addAll(translations.map(
          (key, value) => MapEntry(key, Map<String, dynamic>.from(value))));
    }

    final remoteUrl = i18nConfig['remoteUrl'] as String?;
    if (remoteUrl != null) {
      await _loadRemoteTranslations(remoteUrl);
    }

    notifyListeners();
  }

  /// Load translations from remote URL
  Future<void> _loadRemoteTranslations(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        data.forEach((locale, translations) {
          if (translations is Map) {
            _translations[locale] = Map<String, dynamic>.from(translations);
          }
        });
        _logger.debug('Loaded remote translations from: $url');
      } else {
        _logger.error(
            'Failed to load remote translations: ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Error loading remote translations', e);
    }
  }

  /// Get a translated string with dot notation support
  String translate(String key, {Map<String, dynamic>? params}) {
    final keys = key.split('.');
    dynamic value = _translations[_currentLocale];

    for (final k in keys) {
      if (value is Map) {
        value = value[k];
      } else {
        break;
      }
    }

    if (value == null && _currentLocale != _fallbackLocale) {
      value = _getFromLocale(_fallbackLocale, keys);
    }

    if (value is String && params != null) {
      return _interpolate(value, params);
    }

    return value?.toString() ?? key;
  }

  /// Get value from locale with keys path
  dynamic _getFromLocale(String locale, List<String> keys) {
    dynamic value = _translations[locale];

    for (final key in keys) {
      if (value is Map) {
        value = value[key];
      } else {
        return null;
      }
    }

    return value;
  }

  /// Interpolate parameters into string
  String _interpolate(String value, Map<String, dynamic> params) {
    String result = value;
    params.forEach((key, val) {
      result = result.replaceAll('{{$key}}', val.toString());
      result = result.replaceAll('{$key}', val.toString());
    });
    return result;
  }

  /// Plural form support
  String plural(String key, int count, {Map<String, dynamic>? params}) {
    final pluralKey = '$key.${_getPluralForm(count)}';
    return translate(pluralKey, params: {...?params, 'count': count});
  }

  /// Get plural form based on count
  String _getPluralForm(int count) {
    // Simple English plural rules - can be extended for other languages
    if (_currentLocale.startsWith('en')) {
      if (count == 0) return 'zero';
      if (count == 1) return 'one';
      return 'other';
    }

    // Default rule
    return count == 1 ? 'one' : 'other';
  }

  /// Check if a locale is supported
  bool isLocaleSupported(String locale) {
    return _translations.containsKey(locale);
  }

  /// Get all supported locales
  List<String> getSupportedLocales() {
    return _translations.keys.toList();
  }

  /// Clear all translations
  void clear() {
    _translations.clear();
  }

  /// Handle i18n key format from MCP UI DSL
  /// Format: "i18n:key" or "i18n:key:arg1,arg2"
  String? resolveI18nString(String? value) {
    if (value == null || !value.startsWith('i18n:')) {
      return value;
    }

    // Remove i18n: prefix
    final content = value.substring(5);

    // Check for arguments
    final parts = content.split(':');
    final key = parts[0];

    Map<String, dynamic>? params;
    if (parts.length > 1) {
      // Parse arguments
      params = {};
      final argPairs = parts[1].split(',');
      for (final pair in argPairs) {
        final keyValue = pair.split('=');
        if (keyValue.length == 2) {
          params[keyValue[0]] = keyValue[1];
        }
      }
    }

    return translate(key, params: params);
  }

  /// Resolve a value that might be an i18n key
  dynamic resolve(dynamic value) {
    if (value is String) {
      return resolveI18nString(value) ?? value;
    }
    return value;
  }

  /// Load translations for a specific locale
  void loadLocaleTranslations(
      String locale, Map<String, dynamic> translations) {
    _translations[locale] = translations;
    _logger.debug('Loaded translations for locale: $locale');
    notifyListeners();
  }

  /// Get nested value from translations
  dynamic getNestedValue(String locale, String path) {
    final keys = path.split('.');
    return _getFromLocale(locale, keys);
  }
}

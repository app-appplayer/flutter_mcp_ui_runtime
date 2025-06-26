import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sets up common test configuration
void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    // Mock SharedPreferences for all tests
    SharedPreferences.setMockInitialValues({});
  });
}
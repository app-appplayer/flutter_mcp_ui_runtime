import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/services/dialog_service.dart';

void main() {
  group('DialogService Tests', () {
    late DialogService dialogService;

    setUp(() {
      dialogService = DialogService(enableDebugMode: true);
    });

    tearDown(() {
      dialogService.onDispose();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await dialogService.onInitialize({});
        // No exceptions should be thrown
        expect(true, isTrue);
      });

      test('should create with debug mode enabled', () {
        final service = DialogService(enableDebugMode: true);
        expect(service.enableDebugMode, isTrue);
      });

      test('should create with debug mode disabled', () {
        final service = DialogService(enableDebugMode: false);
        expect(service.enableDebugMode, isFalse);
      });
    });

    group('Dialog Management', () {
      testWidgets('should build alert dialog correctly', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              // Test building dialog components
              final dialogAction = DialogAction(
                text: 'OK',
                onPressed: () {},
              );
              
              // Verify dialog action creation
              expect(dialogAction.text, equals('OK'));
              expect(dialogAction.isDefault, isFalse);
              expect(dialogAction.isDestructive, isFalse);
              
              return const Text('Test');
            },
          ),
        ));
      });

      test('DialogAction should handle default button', () {
        final action = DialogAction(
          text: 'Confirm',
          onPressed: () {},
          isDefault: true,
        );
        
        expect(action.text, equals('Confirm'));
        expect(action.isDefault, isTrue);
        expect(action.isDestructive, isFalse);
      });

      test('DialogAction should handle destructive button', () {
        final action = DialogAction(
          text: 'Delete',
          onPressed: () {},
          isDestructive: true,
        );
        
        expect(action.text, equals('Delete'));
        expect(action.isDefault, isFalse);
        expect(action.isDestructive, isTrue);
      });
    });

    group('DialogType enum', () {
      test('should have all expected types', () {
        expect(DialogType.values.length, equals(5));
        expect(DialogType.values, contains(DialogType.normal));
        expect(DialogType.values, contains(DialogType.alert));
        expect(DialogType.values, contains(DialogType.confirm));
        expect(DialogType.values, contains(DialogType.input));
        expect(DialogType.values, contains(DialogType.custom));
      });
    });

    group('SnackbarType enum', () {
      test('should have all expected types', () {
        expect(SnackbarType.values.length, equals(4));
        expect(SnackbarType.values, contains(SnackbarType.info));
        expect(SnackbarType.values, contains(SnackbarType.success));
        expect(SnackbarType.values, contains(SnackbarType.error));
        expect(SnackbarType.values, contains(SnackbarType.warning));
      });
    });

    group('Context Provider', () {
      test('should throw UnimplementedError when getting context', () {
        // The service requires a context provider to be implemented
        // This test verifies the expected behavior when it's not provided
        expect(
          () => dialogService.showAlert(message: 'Test'),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });

    group('Overlay Management', () {
      test('should handle overlay cleanup on dispose', () async {
        // Test that dispose cleans up overlays without throwing
        await dialogService.onDispose();
        // No exceptions should be thrown
        expect(true, isTrue);
      });
    });
  });

  group('DialogService Mock Tests', () {
    late MockDialogService mockService;

    setUp(() {
      mockService = MockDialogService();
    });

    test('showAlert should track calls correctly', () async {
      await mockService.showAlert(
        message: 'Test Alert',
        title: 'Alert Title',
      );
      
      expect(mockService.lastMessage, equals('Test Alert'));
      expect(mockService.lastTitle, equals('Alert Title'));
    });

    test('showConfirm should return true when confirmed', () async {
      mockService.nextConfirmResult = true;
      
      final result = await mockService.showConfirm(
        message: 'Confirm this?',
        title: 'Confirmation',
      );
      
      expect(result, isTrue);
      expect(mockService.lastMessage, equals('Confirm this?'));
    });

    test('showConfirm should return false when cancelled', () async {
      mockService.nextConfirmResult = false;
      
      final result = await mockService.showConfirm(
        message: 'Confirm this?',
      );
      
      expect(result, isFalse);
    });

    test('showInput should return entered text', () async {
      mockService.nextInputResult = 'User Input';
      
      final result = await mockService.showInput(
        title: 'Enter Text',
        hint: 'Type here',
        initialValue: 'Initial',
      );
      
      expect(result, equals('User Input'));
      expect(mockService.lastTitle, equals('Enter Text'));
    });

    test('showInput should return null when cancelled', () async {
      mockService.nextInputResult = null;
      
      final result = await mockService.showInput(
        title: 'Enter Text',
      );
      
      expect(result, isNull);
    });

    test('showBottomSheet should track calls', () async {
      await mockService.showBottomSheet(
        content: const Text('Sheet Content'),
        height: 300,
      );
      
      expect(mockService.bottomSheetCalls, equals(1));
    });

    test('showLoading and hideLoading should track state', () {
      expect(mockService.isLoadingShowing, isFalse);
      
      mockService.showLoading(message: 'Loading...');
      expect(mockService.isLoadingShowing, isTrue);
      expect(mockService.lastLoadingMessage, equals('Loading...'));
      
      mockService.hideLoading();
      expect(mockService.isLoadingShowing, isFalse);
    });

    test('showSnackbar should track snackbar calls', () {
      mockService.showSnackbar(
        message: 'Success!',
        type: SnackbarType.success,
      );
      
      expect(mockService.snackbarCalls, equals(1));
      expect(mockService.lastSnackbarMessage, equals('Success!'));
      expect(mockService.lastSnackbarType, equals(SnackbarType.success));
    });
  });
}

/// Mock implementation for testing
class MockDialogService extends DialogService {
  String? lastMessage;
  String? lastTitle;
  bool nextConfirmResult = false;
  String? nextInputResult;
  int bottomSheetCalls = 0;
  int snackbarCalls = 0;
  bool isLoadingShowing = false;
  String? lastLoadingMessage;
  String? lastSnackbarMessage;
  SnackbarType? lastSnackbarType;

  MockDialogService() : super(enableDebugMode: true);

  @override
  Future<void> showAlert({
    required String message,
    String? title,
    String confirmText = 'OK',
  }) async {
    lastMessage = message;
    lastTitle = title;
  }

  @override
  Future<bool> showConfirm({
    required String message,
    String? title,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    lastMessage = message;
    lastTitle = title;
    return nextConfirmResult;
  }

  @override
  Future<String?> showInput({
    String? title,
    String? hint,
    String? initialValue,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
  }) async {
    lastTitle = title;
    return nextInputResult;
  }

  @override
  Future<T?> showBottomSheet<T>({
    required Widget content,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) async {
    bottomSheetCalls++;
    return null;
  }

  @override
  void showLoading({String? message, bool barrierDismissible = false}) {
    isLoadingShowing = true;
    lastLoadingMessage = message;
  }

  @override
  void hideLoading() {
    isLoadingShowing = false;
  }

  @override
  void showSnackbar({
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    snackbarCalls++;
    lastSnackbarMessage = message;
    lastSnackbarType = type;
  }

}
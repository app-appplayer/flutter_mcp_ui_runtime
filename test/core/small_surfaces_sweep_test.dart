// The small public surfaces nothing had called.
//
// Exception messages, identity getters, storage refusals, resolver
// fallbacks — each is one or two lines, and each is read by somebody outside
// this package: a host printing an error, a document asking whether it may
// promote, an executor answering a write it could not perform. A `toString`
// that loses its subject and a getter that answers the wrong way are both
// invisible from inside the runtime and obvious from outside it.

import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/entry/entry_context.dart';
import 'package:flutter_mcp_ui_runtime/src/entry/entry_session.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/path_validator.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/qr_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('exceptions name their subject', () {
    test('a path security violation says what was refused', () {
      const e = PathSecurityException('".." segments are not allowed');

      expect(e.toString(), contains('PathSecurityException'));
      expect(e.toString(), contains('not allowed'),
          reason: 'this is what a host logs; a bare type name tells whoever '
              'reads the log nothing about which path was refused');
    });

    test('a payload too long for a QR says how long it was', () {
      final e = QrTooLongException(4296);

      expect(e.toString(), contains('4296'),
          reason: 'the author has to know how far over the limit they are to '
              'decide what to drop');
    });
  });

  group('AssetRef', () {
    test('prints its form and its uri', () {
      final ref = AssetRef.parse('assets/logo.png')!;

      expect(ref.toString(), contains('flutterAsset'));
      expect(ref.toString(), contains('assets/logo.png'),
          reason: 'asset failures are diagnosed from this line — the form '
              'says which reader was used and the uri says on what');
    });
  });

  group('EntrySession — what a document may ask for', () {
    test('with no host wiring at all it reports no support', () {
      final session = EntrySession(stateManager: StateManager());

      expect(session.hasHostSupport, isFalse,
          reason: '§8.9.6: a runtime with no host behind it says so, so a '
              'document can hide the button rather than offering an action '
              'that quietly does nothing');
      expect(session.canPromote, isFalse);
      expect(session.canRelease, isFalse);
    });

    test('a promoter alone makes the surface supported, but release is not',
        () {
      final session = EntrySession(stateManager: StateManager())
        ..adoptIdentity(const IdentityContext(canPromote: true))
        ..registerPromotion(
          onPromote: () async =>
              const IdentityPromotion.promoted(IdentityContext()),
        );

      expect(session.hasHostSupport, isTrue);
      expect(session.canPromote, isTrue);
      expect(session.canRelease, isFalse,
          reason: 'the two handlers are wired separately, and offering '
              'release because promote exists is an action with nothing '
              'behind it');
    });

    test('an identity that cannot be promoted refuses even with a handler',
        () {
      final session = EntrySession(stateManager: StateManager())
        ..adoptIdentity(const IdentityContext())
        ..registerPromotion(
          onPromote: () async =>
              const IdentityPromotion.promoted(IdentityContext()),
        );

      expect(session.canPromote, isFalse,
          reason: 'the host can promote in general; this identity says it is '
              'not a candidate, and that answer wins');
    });
  });
}

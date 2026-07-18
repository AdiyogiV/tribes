import 'package:aurogram/features/baba/domain/baba_auth_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BabaAuthIdentity', () {
    test('anonymous-to-secured upgrade invalidates a same-uid warm session',
        () {
      const guest = BabaAuthIdentity(uid: 'guest-uid', isAnonymous: true);
      const secured = BabaAuthIdentity(uid: 'guest-uid', isAnonymous: false);

      expect(guest.account, 'guest');
      expect(secured.account, 'secured');
      expect(guest.requiresSessionRefresh(secured), isTrue);
    });

    test('an unchanged secured identity keeps its warm session', () {
      const before = BabaAuthIdentity(uid: 'user-uid', isAnonymous: false);
      const after = BabaAuthIdentity(uid: 'user-uid', isAnonymous: false);

      expect(before.requiresSessionRefresh(after), isFalse);
    });

    test('switching uid invalidates cached user-backed data', () {
      const first = BabaAuthIdentity(uid: 'first-uid', isAnonymous: false);
      const second = BabaAuthIdentity(uid: 'second-uid', isAnonymous: false);

      expect(first.requiresSessionRefresh(second), isTrue);
    });
  });
}

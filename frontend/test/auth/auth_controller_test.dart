import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_exception.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fakes.dart';

void main() {
  late FakeApiClient api;
  late FakeTokenStorage tokens;
  late AuthController auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeApiClient();
    tokens = FakeTokenStorage();
    auth = AuthController(api: api, tokens: tokens);
  });

  test('restore without token -> guest, no network call', () async {
    api.onMe = () async => fail('không được gọi API');
    await auth.restore();
    expect(auth.status, AuthStatus.guest);
  });

  test('restore with valid token -> authenticated and fires onSignedIn',
      () async {
    tokens.token = 't';
    api.onMe = () async => testUser;
    var signedIn = 0;
    auth.onSignedIn = () => signedIn++;
    await auth.restore();
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.currentUser?.username, 'an_nguyen');
    expect(auth.isOffline, false);
    expect(signedIn, 1);
  });

  test('restore 401 -> clears token, guest', () async {
    tokens.token = 'old';
    api.onMe = () async => throw const ApiException('x', statusCode: 401);
    await auth.restore();
    expect(auth.status, AuthStatus.guest);
    expect(tokens.token, isNull);
  });

  test('restore network error -> keeps token, offline with cached user',
      () async {
    tokens.token = 't';
    api.onMe = () async => testUser;
    await auth.restore(); // lưu cache user
    api.onMe = () async =>
        throw const ApiException(ApiException.networkMessage, isNetwork: true);
    final again = AuthController(api: api, tokens: tokens);
    await again.restore();
    expect(again.status, AuthStatus.authenticated);
    expect(again.isOffline, true);
    expect(again.currentUser?.userId, 7);
    expect(tokens.token, 't');
  });

  test('login success stores token and user', () async {
    api.onLogin = () async => const AuthResult(token: 'jwt', user: testUser);
    final ok = await auth.login(' an ', 'secret1');
    expect(ok, true);
    expect(auth.isAuthenticated, true);
    expect(tokens.token, 'jwt');
    expect(auth.busy, false);
    expect(auth.lastError, isNull);
  });

  test('login failure sets error, stays guest', () async {
    auth.status; // unknown
    api.onLogin =
        () async => throw const ApiException('Sai mật khẩu', statusCode: 401);
    final ok = await auth.login('an', 'bad');
    expect(ok, false);
    expect(auth.lastError, 'Sai mật khẩu');
    expect(auth.isAuthenticated, false);
    expect(tokens.token, isNull);
  });

  test('busy blocks double submit', () async {
    var calls = 0;
    api.onLogin = () async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const AuthResult(token: 'jwt', user: testUser);
    };
    final a = auth.login('an', 'x');
    final b = auth.login('an', 'x');
    expect(await b, false);
    expect(await a, true);
    expect(calls, 1);
  });

  test('logout clears token and cached user', () async {
    api.onLogin = () async => const AuthResult(token: 'jwt', user: testUser);
    await auth.login('an', 'x');
    await auth.logout();
    expect(auth.status, AuthStatus.guest);
    expect(auth.currentUser, isNull);
    expect(tokens.token, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cached_user'), isNull);
  });

  test('handleUnauthorized while authenticated -> guest with message',
      () async {
    api.onLogin = () async => const AuthResult(token: 'jwt', user: testUser);
    await auth.login('an', 'x');
    auth.handleUnauthorized();
    await Future<void>.delayed(Duration.zero);
    expect(auth.status, AuthStatus.guest);
    expect(auth.lastError, contains('hết hạn'));
  });

  test('updateProfile updates currentUser', () async {
    api.onLogin = () async => const AuthResult(token: 'jwt', user: testUser);
    await auth.login('an', 'x');
    api.onUpdateMe = (name) async => AppUser(
        userId: 7,
        username: 'an_nguyen',
        email: 'an@email.com',
        fullName: name);
    expect(await auth.updateProfile('  Tên mới '), true);
    expect(auth.currentUser?.fullName, 'Tên mới');
  });
}

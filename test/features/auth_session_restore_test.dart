import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/core/storage/session_store.dart';
import 'package:kalla_lai/features/auth/application/auth_gateway.dart';

void main() {
  const refreshBody = <String, dynamic>{
    'accessToken': 'access-new',
    'refreshToken': 'refresh-new',
    'user': <String, dynamic>{
      'id': 'user-1',
      'email': 'worker@example.com',
      'fullName': 'Worker One',
      'roles': ['WORKER'],
      'onboardingComplete': true,
      'identityStatus': 'VERIFIED',
    },
  };

  ApiAuthGateway gatewayFor(MockClient client) => ApiAuthGateway(
    ApiClient(baseUrl: 'https://api.example.test', httpClient: client),
  );

  setUp(() {
    SessionStore.clear();
    SessionStore.save(
      refreshToken: 'refresh-saved',
      accessToken: 'access-saved',
      email: 'worker@example.com',
    );
  });

  test('restores a saved session and stores the rotated tokens', () async {
    final gateway = gatewayFor(
      MockClient((request) async {
        expect(request.url.path, '/v1/auth/refresh');
        expect(
          (jsonDecode(request.body) as Map<String, dynamic>)['refreshToken'],
          'refresh-saved',
        );
        return http.Response(
          jsonEncode(refreshBody),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final user = await gateway.restoreSession();

    expect(user?.email, 'worker@example.com');
    expect(user?.roles, contains('WORKER'));
    expect(user?.identityStatus, 'VERIFIED');
    expect(SessionStore.refreshToken, 'refresh-new');
    expect(SessionStore.accessToken, 'access-new');
  });

  test('keeps the saved session when the server has a transient failure', () async {
    final gateway = gatewayFor(
      MockClient(
        (request) async => http.Response(
          '{"error":{"code":"INTERNAL","message":"try again"}}',
          500,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final user = await gateway.restoreSession();

    expect(user, isNull);
    expect(SessionStore.refreshToken, 'refresh-saved');
    expect(SessionStore.accessToken, 'access-saved');
  });

  test('keeps the saved session when the network is unreachable', () async {
    final gateway = gatewayFor(
      MockClient((request) async => throw http.ClientException('offline')),
    );

    final user = await gateway.restoreSession();

    expect(user, isNull);
    expect(SessionStore.refreshToken, 'refresh-saved');
    expect(SessionStore.accessToken, 'access-saved');
  });

  test('clears the saved session only when the token is rejected', () async {
    final gateway = gatewayFor(
      MockClient(
        (request) async => http.Response(
          '{"error":{"code":"SESSION_EXPIRED","message":"expired"}}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final user = await gateway.restoreSession();

    expect(user, isNull);
    expect(SessionStore.refreshToken, isNull);
    expect(SessionStore.accessToken, isNull);
  });
}

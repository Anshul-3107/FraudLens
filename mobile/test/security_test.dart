import 'package:flutter_test/flutter_test.dart';
import 'package:fraudlens/models/user.dart';
import 'package:fraudlens/services/api_client.dart';
import 'package:fraudlens/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('AuthService migrates legacy plaintext token to secure storage and removes SharedPreferences entry', () async {
    SharedPreferences.setMockInitialValues({
      'fraudlens_auth_token': 'legacy_secret_token_123',
      'fraudlens_user_cache': '{"id":7,"username":"alice","email":"alice@example.com","is_staff":false,"card_count":1}',
    });

    final auth = AuthService();
    final token = await auth.getStoredToken();
    final user = await auth.getStoredUser();

    expect(token, 'legacy_secret_token_123');
    expect(user?.username, 'alice');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fraudlens_auth_token'), isNull);
    expect(prefs.getString('fraudlens_user_cache'), isNull);

    await auth.saveToken('fresh_token_456');
    expect(ApiClient.instance.authHeaders, {
      'Authorization': 'Token fresh_token_456',
    });
    await auth.saveUser(
      UserMe(
        id: 7,
        username: 'alice',
        email: 'alice@example.com',
        isStaff: false,
        cardCount: 1,
      ),
    );
    expect(prefs.getString('fraudlens_auth_token'), isNull);
    expect(prefs.getString('fraudlens_user_cache'), isNull);

    await auth.clearSession();
    expect(ApiClient.instance.authHeaders, isEmpty);
    expect(await auth.getStoredToken(), isNull);
  });
}

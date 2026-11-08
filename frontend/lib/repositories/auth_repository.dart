import '../models/user.dart';
import '../services/api/api_client.dart';
import '../services/storage/secure_storage_service.dart';

/// Authentication + profile. Token and a cached copy of the user live in secure storage so the app
/// can open (and work with local data) with no connection.
class AuthRepository {
  final ApiClient api;
  final SecureStorageService storage;
  AuthRepository(this.api, this.storage);

  Future<String?> readToken() => storage.readToken();
  Future<User?> cachedUser() => storage.readUser();

  Future<User> register({required String name, required String email, required String password, String studentId = '', String program = ''}) async {
    final res = await api.post('/auth/register',
        {'name': name.trim(), 'email': email.trim(), 'password': password, 'studentId': studentId.trim(), 'program': program.trim()},
        auth: false);
    return _store(res);
  }

  Future<User> login(String email, String password) async {
    final res = await api.post('/auth/login', {'email': email.trim(), 'password': password}, auth: false);
    return _store(res);
  }

  Future<User> fetchMe() async {
    final res = await api.get('/auth/me');
    final u = User.fromJson(res['data'] as Map<String, dynamic>);
    await storage.saveUser(u);
    return u;
  }

  Future<User> updateProfile({required String name, required String studentId, required String program}) async {
    final res = await api.put('/users/profile', {'name': name.trim(), 'studentId': studentId.trim(), 'program': program.trim()});
    final u = User.fromJson(res['data'] as Map<String, dynamic>);
    await storage.saveUser(u);
    return u;
  }

  Future<void> logout() => storage.clearSession();

  Future<User> _store(Map<String, dynamic> res) async {
    final data = res['data'] as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null) throw StateError('Invalid server response: missing token');
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await storage.saveToken(token);
    await storage.saveUser(user);
    return user;
  }
}

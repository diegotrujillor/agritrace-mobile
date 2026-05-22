import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/users_service.dart';
import 'auth_provider.dart';

final usersServiceProvider = Provider<UsersService>(
  (ref) => UsersService(ref.read(apiServiceProvider)),
);

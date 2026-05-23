import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/uploads_service.dart';
import 'auth_provider.dart';

/// Provider wiring for [UploadsService]. Mirrors `feedbackServiceProvider`:
/// a thin [Provider] that hands the shared [ApiService] (and its
/// `_AuthInterceptor`) to the service. No notifier needed — the consuming
/// screen owns its own `uploading` flag (identical to
/// `_ActivityFormState._submitting`).
final uploadsServiceProvider = Provider<UploadsService>(
  (ref) => UploadsService(ref.read(apiServiceProvider)),
);

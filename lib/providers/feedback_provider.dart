import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/feedback_service.dart';
import 'auth_provider.dart';

/// Provider wiring for [FeedbackService]. Mirrors `usersServiceProvider`
/// — a thin Provider that hands the [ApiService] to the service. No
/// notifier needed: the screen owns its own `busy` state, identical to
/// `ProfileScreen._exportBusy` / `_deleteBusy`.
final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(ref.read(apiServiceProvider)),
);

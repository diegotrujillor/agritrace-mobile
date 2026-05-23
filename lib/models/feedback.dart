/// DTOs for the `POST /v1/feedback` in-app issue reporting endpoint.
///
/// The contract is frozen by the backend agent owning `/v1/feedback`
/// (see `agritrace-backend` v0.5.0). Field names below MUST stay in sync
/// with that contract — adding/renaming fields is a coordinated change.
library;

/// User-selected category for the report. The `apiValue` getter is the
/// wire form expected by the backend (`bug` / `feature` / `other`); the
/// Spanish label is owned by the UI layer (see `ReportIssueScreen`).
enum FeedbackCategory {
  bug,
  feature,
  other;

  /// Wire value sent in the JSON body. Stable identifier — do not change
  /// without coordinating with the backend.
  String get apiValue => switch (this) {
        FeedbackCategory.bug => 'bug',
        FeedbackCategory.feature => 'feature',
        FeedbackCategory.other => 'other',
      };
}

/// Device metadata captured automatically and attached to the report so
/// the GitHub issue carries reproducible context. Mirrors the backend
/// JSON shape: `{ model, platform, osVersion }`.
class FeedbackDevice {
  const FeedbackDevice({
    required this.model,
    required this.platform,
    required this.osVersion,
  });

  /// Marketing model name, e.g. `"Pixel 7 Pro"`.
  final String model;

  /// `"android"` | `"ios"`. iOS is not shipping in MVP — see CLAUDE.md
  /// "Android-only project" — but the field is reserved for forward compat.
  final String platform;

  /// Human-readable OS version string, e.g. `"Android 14"`.
  final String osVersion;

  Map<String, dynamic> toJson() => {
        'model': model,
        'platform': platform,
        'osVersion': osVersion,
      };
}

/// Successful result of `POST /v1/feedback`. The backend creates a GitHub
/// issue and returns the URL + issue number so the UI can deep-link the
/// user back to the issue if they want to track it.
class FeedbackSubmitted {
  const FeedbackSubmitted({
    required this.issueUrl,
    required this.issueNumber,
  });

  final String issueUrl;
  final int issueNumber;

  /// Parses the inner `data` payload of the `{ success, data }` envelope.
  /// Throws [FormatException] when either field is missing or the wrong type.
  factory FeedbackSubmitted.fromJson(Map<String, dynamic> json) {
    final url = json['issueUrl'];
    final number = json['issueNumber'];
    if (url is! String || url.isEmpty) {
      throw const FormatException(
        'Invalid feedback response: issueUrl is missing or empty',
      );
    }
    if (number is int) {
      return FeedbackSubmitted(issueUrl: url, issueNumber: number);
    }
    // Tolerate JSON int-as-num (Dio sometimes hands back num for big ints).
    if (number is num) {
      return FeedbackSubmitted(issueUrl: url, issueNumber: number.toInt());
    }
    throw const FormatException(
      'Invalid feedback response: issueNumber is missing or not an int',
    );
  }
}

/// Thrown when the backend rejects a feedback submission with HTTP 429
/// (rate limit). Carries a pre-localised user-facing Spanish message so
/// the UI can render it directly — bypasses the generic `parseApiError`
/// path because the 5-per-day limit has its own copy.
class FeedbackRateLimitException implements Exception {
  const FeedbackRateLimitException(this.userMessage);

  /// Spanish user-facing copy.
  final String userMessage;

  @override
  String toString() => 'FeedbackRateLimitException($userMessage)';
}

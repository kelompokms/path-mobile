import 'dart:convert';

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Validates an email address without artificially restricting TLD lengths
/// or rejecting `+` aliases.
bool isValidEmailAddress(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  return _emailPattern.hasMatch(trimmed);
}

/// Validates an E.164 phone number (e.g. `+628123456789`) as required by
/// `path-api`'s `validate:"required,e164"`.
bool isValidE164Phone(String raw) {
  final trimmed = raw.trim();
  return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(trimmed);
}

/// Extracts a human-readable error message from a `path-api` JSON error body.
///
/// Prefers detailed field messages inside `errors[]` (produced by Echo's
/// `ValidationErrorHandler`, whose top-level `message` is always `"invalid"`),
/// falling back to `message` and finally [fallback].
String extractApiErrorMessage(String body, String fallback) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final rawErrors = decoded['errors'];
      if (rawErrors is List && rawErrors.isNotEmpty) {
        final details = <String>[];
        for (final item in rawErrors) {
          if (item is Map<String, dynamic>) {
            final msg = (item['message'] ?? '').toString().trim();
            if (msg.isNotEmpty) {
              details.add(msg);
            }
          } else if (item is String && item.trim().isNotEmpty) {
            details.add(item.trim());
          }
        }
        if (details.isNotEmpty) {
          return details.join(', ');
        }
      }
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
  } catch (_) {}
  return fallback;
}

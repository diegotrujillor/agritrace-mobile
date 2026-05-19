String? validateEmail(String? value) {
  if (value == null || value.isEmpty) return 'El email es requerido';
  if (value.length > 254) return 'El email es demasiado largo';
  // Slightly stricter than the previous `[^@]+@[^@]+\.[^@]+`: forbids spaces
  // and requires a dot in the domain. Server is the authoritative validator;
  // this is a UX-only filter to reject obviously bad input.
  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!emailRegex.hasMatch(value.trim())) return 'Ingresa un email válido';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'La contraseña es requerida';
  if (value.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
  if (value.length > 128) return 'La contraseña es demasiado larga';
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Debe incluir al menos una minúscula';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Debe incluir al menos una mayúscula';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Debe incluir al menos un número';
  }
  return null;
}

String? validateFullName(String? value) {
  if (value == null || value.trim().isEmpty) return 'El nombre completo es requerido';
  final trimmed = value.trim();
  if (trimmed.length < 3) return 'El nombre debe tener al menos 3 caracteres';
  if (trimmed.length > 100) return 'El nombre es demasiado largo';
  return null;
}

String? validatePhone(String? value) {
  if (value == null || value.isEmpty) return 'El teléfono es requerido';
  final trimmed = value.trim();
  if (trimmed.length > 20) return 'El teléfono es demasiado largo';
  final phoneRegex = RegExp(r'^\+?[\d\s\-]{7,20}$');
  if (!phoneRegex.hasMatch(trimmed)) return 'Ingresa un teléfono válido';
  return null;
}

/// Generic non-empty text validator for short free-text fields (farm name,
/// plot name). Server is authoritative; this is a UX-only filter.
String? validateRequiredText(String? value) {
  if (value == null || value.trim().isEmpty) return 'Este campo es requerido';
  final trimmed = value.trim();
  if (trimmed.length < 2) return 'Debe tener al menos 2 caracteres';
  if (trimmed.length > 120) return 'Es demasiado largo';
  return null;
}

/// Area in hectares: required, parseable, and positive. Capped generously at
/// 100 000 ha to reject obvious typos (extra zeros) while not constraining
/// legitimate input; the server enforces the authoritative business bounds.
String? validateArea(String? value) {
  if (value == null || value.trim().isEmpty) return 'El área es requerida';
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  if (parsed == null) return 'Ingresa un número válido';
  if (parsed <= 0) return 'El área debe ser mayor a 0';
  if (parsed > 100000) return 'El área es demasiado grande';
  return null;
}

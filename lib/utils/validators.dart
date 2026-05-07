String? validateEmail(String? value) {
  if (value == null || value.isEmpty) return 'El email es requerido';
  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!emailRegex.hasMatch(value)) return 'Ingresa un email válido';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'La contraseña es requerida';
  if (value.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
  return null;
}

String? validateFullName(String? value) {
  if (value == null || value.trim().isEmpty) return 'El nombre completo es requerido';
  if (value.trim().length < 3) return 'El nombre debe tener al menos 3 caracteres';
  return null;
}

String? validatePhone(String? value) {
  if (value == null || value.isEmpty) return 'El teléfono es requerido';
  final phoneRegex = RegExp(r'^\+?[\d\s\-]{7,15}$');
  if (!phoneRegex.hasMatch(value.trim())) return 'Ingresa un teléfono válido';
  return null;
}

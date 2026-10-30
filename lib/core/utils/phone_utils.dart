/// Phone helpers for the India-only (+91) login flow.
library;

/// Returns the 10-digit national number, or null if the input isn't one.
/// Accepts what people actually type: "98765 43210", "+91 98765 43210",
/// "919876543210", "09876543210".
String? indianNationalNumber(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits.length == 10 ? digits : null;
}

/// E.164 form, e.g. +919876543210. Falls back to the raw digits with a +91
/// prefix if the input isn't a recognisable 10-digit number (the validator
/// should have rejected it before this point).
String normalizeIndianPhone(String input) {
  final national = indianNationalNumber(input);
  if (national != null) return '+91$national';
  return '+91${input.replaceAll(RegExp(r'\D'), '')}';
}

/// Form validator shared by the login and register screens.
String? validateIndianPhone(String? value) {
  if (value == null || value.trim().isEmpty) return 'Phone number is required';
  if (indianNationalNumber(value) == null) {
    return 'Enter a valid 10-digit phone number';
  }
  return null;
}

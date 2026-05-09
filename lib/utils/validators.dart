class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    // Basic institutional regex for email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid institutional email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Security password is required';
    }
    if (value.trim().length < 6) {
      return 'Institutional security requires at least 6 characters';
    }
    return null;
  }

  static String? validateTransactionId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Transaction / Reference ID is mandatory';
    }
    if (value.trim().length < 5) {
      return 'Please enter a valid audit-trail reference ID';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Payment amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      return 'Amount must be a valid institutional figure';
    }
    return null;
  }
}

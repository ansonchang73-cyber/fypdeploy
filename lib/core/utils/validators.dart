class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }
}
class AuthValidator {
  static String? validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    if (!email.endsWith('@gmail.com')) return 'Please use a @gmail.com email';
    return null;
  }

  static String? validatePassword(String password) {
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? validateName(String name) {
    if (name.isEmpty) return 'Full name is required';
    return null;
  }
}
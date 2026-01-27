import 'package:get/get.dart';

/// Controller to manage the selected role in the app using GetX.
enum UserRole { user, dealer }

class UserController extends GetxController {
  final Rxn<UserRole> _role = Rxn<UserRole>();

  /// Current selected role. Null if no role chosen yet.
  UserRole? get role => _role.value;

  /// Expose Rx if you want to use obx directly.
  Rxn<UserRole> get roleRx => _role;

  /// Convenience checks
  bool get isUser => _role.value == UserRole.user;
  bool get isDealer => _role.value == UserRole.dealer;
  bool get hasRole => _role.value != null;

  /// Choose a role.
  void chooseRole(UserRole chosen) {
    if (_role.value == chosen) return;
    _role.value = chosen;
    // If you're using GetBuilder, call update(); otherwise Rx notifies observers.
  }

  /// Clear the chosen role.
  void clearRole() {
    if (_role.value == null) return;
    _role.value = null;
  }

  /// Optional: set role from string (case-insensitive).
  void chooseRoleFromString(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'user') {
      chooseRole(UserRole.user);
    } else if (normalized == 'dealer') {
      chooseRole(UserRole.dealer);
    } else {
      throw ArgumentError('Unknown role: $value');
    }
  }
}

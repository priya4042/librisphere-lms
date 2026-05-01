enum UserRole { admin, librarian, guest }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.librarian:
        return 'Librarian';
      case UserRole.guest:
        return 'Guest';
    }
  }

  String get key {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.librarian:
        return 'librarian';
      case UserRole.guest:
        return 'guest';
    }
  }

  static UserRole fromKey(String? key) {
    switch (key) {
      case 'admin':
        return UserRole.admin;
      case 'librarian':
        return UserRole.librarian;
      case 'guest':
        return UserRole.guest;
      default:
        return UserRole.admin;
    }
  }
}

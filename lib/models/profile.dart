class ProfileKey {
  const ProfileKey(this.value);
  final String value;
  @override
  bool operator ==(Object other) => other is ProfileKey && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

class Profile {
  const Profile({
    required this.key,
    required this.label,
    this.isDefault = false,
  });
  final ProfileKey key;
  final String label;
  final bool isDefault;
}

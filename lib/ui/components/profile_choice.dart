import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../content.dart';

/// Le nom opaque distingue deux profils portant le même nom d'affichage.
class ProfileChoice extends StatelessWidget {
  const ProfileChoice({
    super.key,
    required this.profile,
    required this.selected,
    this.onTap,
  });
  final Profile profile;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: ListTile(
      title: Text(Content.profileName(profile.label, profile.key.value)),
      subtitle: selected ? const Text(Content.selected) : null,
      trailing: selected
          ? const ExcludeSemantics(child: Icon(Icons.check_circle_outline))
          : null,
      selected: selected,
      onTap: onTap,
    ),
  );
}

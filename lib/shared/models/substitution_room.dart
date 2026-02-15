class SubstitutionRoom {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isInsideSubstitution;
  final bool joined;

  const SubstitutionRoom({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.isInsideSubstitution,
    required this.joined,
  });
}

class SubstitutionRoom {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isInsideSubstitution;
  final bool joined;
  final String? topic;
  final int? numJoinedMembers;
  final bool worldReadable;

  const SubstitutionRoom({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.isInsideSubstitution,
    required this.joined,
    this.topic,
    this.numJoinedMembers,
    this.worldReadable = false,
  });
}

import '../../models/group.dart';

/// One row per user — guards against cache merge / API drift duplicates.
List<MemberModel> distinctMembersByUserId(List<MemberModel> members) {
  final seen = <String>{};
  final result = <MemberModel>[];
  for (final member in members) {
    if (!seen.add(member.userId)) continue;
    result.add(member);
  }
  return result;
}

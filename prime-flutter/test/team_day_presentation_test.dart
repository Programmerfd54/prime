import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/groups/team_day_presentation.dart';
import 'package:prime/models/group.dart';

GroupModel _group({
  required String id,
  required String skillName,
  int ready = 0,
  int total = 3,
  List<String> waiting = const [],
  bool reported = false,
}) {
  return GroupModel.fromJson({
    'id': id,
    'name': skillName,
    'skill_id': 'skill-$id',
    'skill_name': skillName,
    'status': 'active',
    'is_private': false,
    'is_cross_region': false,
    'max_members': 6,
    'members_count': total,
    'members': List.generate(
      total,
      (i) => {
        'id': 'member-$i',
        'user_id': 'u$i',
        'nickname': 'user$i',
        'role': 'member',
        'active': true,
        'report_status': i < ready ? 'ready' : 'not_ready',
      },
    ),
    'team_day': {
      'ready_count': ready,
      'member_count': total,
      'status': ready >= total ? 'complete' : 'pending',
      'waiting_for': waiting
          .map((name) => {'nickname': name.replaceFirst('@', '')})
          .toList(),
    },
    if (reported)
      'my_today_report': {'reported': true, 'date': '2026-07-31'},
  });
}

void main() {
  test('aggregate sums progress across active groups', () {
    final aggregated = TeamDayPresentationResolver.aggregate([
      _group(
        id: 'g1',
        skillName: 'Утренний фокус',
        waiting: ['@tes', '@wrightags', '@tess'],
      ),
      _group(
        id: 'g2',
        skillName: 'Одна глава',
        waiting: ['@tes', '@sss', '@tess'],
      ),
    ]);

    expect(aggregated.combined.ready, 0);
    expect(aggregated.combined.total, 6);
    expect(aggregated.combined.label, 'Отчёты сегодня · 0 из 6');
    expect(aggregated.groups, hasLength(2));
    expect(
      aggregated.combined.waitingNames,
      containsAll(['@tes', '@wrightags', '@tess', '@sss']),
    );
  });

  test('groupNeedingReport prefers group without today report', () {
    final groups = [
      _group(id: 'g1', skillName: 'A', reported: true),
      _group(id: 'g2', skillName: 'B'),
    ];
    final target = TeamDayPresentationResolver.groupNeedingReport(groups);
    expect(target?.id, 'g2');
  });
}

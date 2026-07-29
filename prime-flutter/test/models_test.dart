import 'package:flutter_test/flutter_test.dart';
import 'package:prime/models/group.dart';
import 'package:prime/models/report.dart';
import 'package:prime/models/user.dart';
import 'package:prime/data/regions.dart';

void main() {
  test('Москва и Московская область разделены в резервном справочнике', () {
    final byCode = {
      for (final region in russianRegions)
        region['code'] as String: region['name'] as String,
    };
    expect(byCode['77'], 'Москва');
    expect(byCode['50'], 'Московская область');
  });

  test('UserModel безопасно применяет значения по умолчанию', () {
    final user = UserModel.fromJson({
      'id': 'user-1',
      'email': 'user@example.com',
      'created_at': '2026-07-04T10:00:00Z',
    });

    expect(user.name, isEmpty);
    expect(user.primePoints, 0);
    expect(user.profileCompleted, isFalse);
  });

  test('WaitingRoomStatus корректно разбирает ответ backend', () {
    final status = WaitingRoomStatus.fromJson({
      'in_queue': true,
      'people_waiting': 3,
      'needed': 6,
      'matched_group_id': 'group-1',
      'region_code': '66',
      'region_name': 'Свердловская область',
      'can_expand_search': true,
      'allow_other_regions': false,
      'expansion_available_at': '2026-07-04T11:00:00Z',
      'online_in_pool': 2,
      'region_searching': 5,
      'skill_searching': 3,
      'median_match_hours': 4.5,
      'slots': [
        {
          'letter': 'A',
          'region_code': '66',
          'region_color_seed': 120,
          'joined_ago_seconds': 42,
        },
      ],
      'events': [
        {'type': 'joined', 'text': 'Участник A присоединился', 'ago_seconds': 42},
      ],
    });

    expect(status.inQueue, isTrue);
    expect(status.peopleWaiting, 3);
    expect(status.needed, 6);
    expect(status.matchedGroupId, 'group-1');
    expect(status.regionCode, '66');
    expect(status.regionName, 'Свердловская область');
    expect(status.canExpandSearch, isTrue);
    expect(status.onlineInPool, 2);
    expect(status.slots.single.letter, 'A');
    expect(status.events.single.type, 'joined');
    expect(status.medianMatchHours, 4.5);
  });

  test('CalendarOut разбирает календарь и статистику', () {
    final calendar = CalendarOut.fromJson({
      'days': [
        {
          'date': '2026-07-04',
          'completed': true,
          'reported': true,
          'prime_awarded': false,
        },
      ],
      'current_streak': 2,
      'successful_days': 4,
      'prime_points': 5,
    });

    expect(calendar.days.single.completed, isTrue);
    expect(calendar.currentStreak, 2);
  });
}

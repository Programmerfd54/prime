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
        {
          'type': 'joined',
          'text': 'Участник A присоединился',
          'ago_seconds': 42
        },
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

  test('WaitingRoomStatus разбирает early-start поля', () {
    final status = WaitingRoomStatus.fromJson({
      'in_queue': true,
      'people_waiting': 3,
      'can_start_early': true,
      'early_start_confirmed': true,
      'early_start_confirmed_count': 2,
      'early_start_waiting_others': true,
      'early_start_pending': false,
      'early_start_needed_confirmations': 3,
      'revision': 9,
      'early_start_request_id': 'request-1',
      'early_start_proposer_name': 'Анна',
      'early_start_expires_at': '2026-07-30T20:00:00Z',
      'early_start_seconds_remaining': 812,
      'early_start_deep_link':
          'prime://waiting-room?skill_id=morning-focus&early_start=request-1',
    });

    expect(status.canStartEarly, isTrue);
    expect(status.earlyStartConfirmed, isTrue);
    expect(status.earlyStartConfirmedCount, 2);
    expect(status.earlyStartWaitingOthers, isTrue);
    expect(status.earlyStartPending, isFalse);
    expect(status.earlyStartNeededConfirmations, 3);
    expect(status.revision, 9);
    expect(status.earlyStartRequestId, 'request-1');
    expect(status.earlyStartProposerName, 'Анна');
    expect(status.earlyStartSecondsRemaining, 812);
    expect(status.earlyStartExpiresAt, DateTime.parse('2026-07-30T20:00:00Z'));
    expect(status.earlyStartDeepLink, contains('request-1'));
  });

  test('GroupModel разбирает realtime, дневной статус и личный результат', () {
    final group = GroupModel.fromJson({
      'id': 'group-1',
      'name': 'Утренний фокус',
      'skill_id': 'morning-focus',
      'status': 'active',
      'revision': 14,
      'is_cross_region': false,
      'max_members': 3,
      'cycle_day': 8,
      'members_count': 1,
      'members': [
        {
          'id': 'member-1',
          'user_id': 'user-1',
          'role': 'creator',
          'active': true,
          'report_status': 'not_ready',
          'check_in_kind': 'starting',
          'check_in_at': '2026-07-30T08:10:00Z',
        },
      ],
      'my_today_report': {
        'date': '2026-07-30',
        'status': 'ready',
        'reported': true,
        'completed': true,
      },
      'personal_result': {
        'ready_days': 5,
        'cycle_ready_days': 18,
        'team_days': 4,
        'support_given': 3,
        'support_received': 2,
        'recovered_hard_days': 1,
        'message': 'Команда помогла сохранить ритм.',
      },
    });

    expect(group.revision, 14);
    expect(group.cycleDay, 8);
    expect(group.members.single.checkInKind, 'starting');
    expect(group.myTodayReport?.reported, isTrue);
    expect(group.personalResult?.readyDays, 5);
    expect(group.personalResult?.supportReceived, 2);
    expect(group.personalResult?.message, contains('ритм'));
  });

  test('WaitingRoomStatus разбирает pending early-start для наблюдателя', () {
    final status = WaitingRoomStatus.fromJson({
      'in_queue': true,
      'people_waiting': 3,
      'can_start_early': true,
      'early_start_confirmed': false,
      'early_start_confirmed_count': 1,
      'early_start_waiting_others': false,
      'early_start_pending': true,
    });

    expect(status.earlyStartPending, isTrue);
    expect(status.earlyStartConfirmed, isFalse);
    expect(status.earlyStartConfirmedCount, 1);
  });

  test('WaitingRoomStatus поддерживает legacy pair-start ключи', () {
    final status = WaitingRoomStatus.fromJson({
      'in_queue': true,
      'can_start_as_pair': true,
      'pair_start_confirmed': false,
      'pair_start_waiting_partner': false,
    });

    expect(status.canStartEarly, isTrue);
    expect(status.earlyStartConfirmed, isFalse);
    expect(status.earlyStartWaitingOthers, isFalse);
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

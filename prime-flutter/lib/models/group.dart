import 'user.dart';

enum GroupStatus {
  forming,
  introduction,
  rulesPending,
  active,
  rotating,
  voting,
  completed,
}

enum MemberRole { creator, member }

enum TeamPulseStatus { calm, high, support, allDone }

class TeamCheckInModel {
  const TeamCheckInModel({
    required this.userId,
    required this.nickname,
    required this.kind,
  });

  final String userId;
  final String nickname;
  final String kind;

  factory TeamCheckInModel.fromJson(Map<String, dynamic> json) =>
      TeamCheckInModel(
        userId: json['user_id'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
      );
}

class TeamPulseModel {
  const TeamPulseModel({
    required this.completedToday,
    required this.totalActive,
    required this.status,
    required this.message,
    required this.checkIns,
    this.dayStatus = 'pending',
    this.waitingFor = const [],
    this.closedAt,
  });

  final int completedToday;
  final int totalActive;
  final TeamPulseStatus status;
  final String message;
  final List<TeamCheckInModel> checkIns;
  final String dayStatus;
  final List<TeamWaitingMember> waitingFor;
  final DateTime? closedAt;

  bool get isTeamDayComplete =>
      dayStatus == 'complete' || status == TeamPulseStatus.allDone;

  factory TeamPulseModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TeamPulseModel(
        completedToday: 0,
        totalActive: 0,
        status: TeamPulseStatus.calm,
        message: 'Нет данных о ритме команды',
        checkIns: [],
      );
    }
    return TeamPulseModel(
      completedToday: json['completed_today'] as int? ?? 0,
      totalActive: json['total_active'] as int? ?? 0,
      status: _pulseStatusFrom(json['status'] as String?),
      message: json['message'] as String? ?? '',
      checkIns: (json['check_ins_today'] as List<dynamic>? ?? [])
          .map((e) => TeamCheckInModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      dayStatus: json['day_status'] as String? ?? 'pending',
      waitingFor: (json['waiting_for'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TeamWaitingMember.fromJson)
          .toList(),
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
    );
  }
}

class TeamWaitingMember {
  const TeamWaitingMember({
    required this.userId,
    required this.name,
    required this.nickname,
  });

  final String userId;
  final String name;
  final String nickname;

  String get displayName =>
      name.trim().isNotEmpty ? name : (nickname.isNotEmpty ? '@$nickname' : 'Участник');

  factory TeamWaitingMember.fromJson(Map<String, dynamic> json) =>
      TeamWaitingMember(
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
      );
}

class TeamDayModel {
  const TeamDayModel({
    required this.date,
    required this.status,
    required this.readyCount,
    required this.memberCount,
    this.waitingFor = const [],
    this.closedAt,
  });

  final DateTime date;
  final String status;
  final int readyCount;
  final int memberCount;
  final List<TeamWaitingMember> waitingFor;
  final DateTime? closedAt;

  bool get isComplete => status == 'complete';
  bool get isPending => status == 'pending';
  int get remaining => (memberCount - readyCount).clamp(0, memberCount);

  factory TeamDayModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TeamDayModel(
        date: DateTime.now(),
        status: 'pending',
        readyCount: 0,
        memberCount: 0,
      );
    }
    return TeamDayModel(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      readyCount: json['ready_count'] as int? ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
      waitingFor: (json['waiting_for'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TeamWaitingMember.fromJson)
          .toList(),
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
    );
  }
}

TeamPulseStatus _pulseStatusFrom(String? raw) => switch (raw) {
      'all_done' => TeamPulseStatus.allDone,
      'high' => TeamPulseStatus.high,
      'support' => TeamPulseStatus.support,
      _ => TeamPulseStatus.calm,
    };

class TeamRecapModel {
  const TeamRecapModel({
    required this.periodStart,
    required this.periodEnd,
    required this.readyReports,
    required this.pacePercent,
    this.bestDay,
    required this.bestDayCount,
    required this.supportSignals,
    required this.message,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final int readyReports;
  final int pacePercent;
  final DateTime? bestDay;
  final int bestDayCount;
  final int supportSignals;
  final String message;

  factory TeamRecapModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TeamRecapModel.empty();
    }
    return TeamRecapModel(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      readyReports: json['ready_reports'] as int? ?? 0,
      pacePercent: json['pace_percent'] as int? ?? 0,
      bestDay: json['best_day'] != null
          ? DateTime.parse(json['best_day'] as String)
          : null,
      bestDayCount: json['best_day_count'] as int? ?? 0,
      supportSignals: json['support_signals'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }

  factory TeamRecapModel.empty() {
    final today = DateTime.now();
    return TeamRecapModel(
      periodStart: today,
      periodEnd: today,
      readyReports: 0,
      pacePercent: 0,
      bestDayCount: 0,
      supportSignals: 0,
      message: 'Нет данных за неделю',
    );
  }
}

class TeamMilestoneModel {
  const TeamMilestoneModel({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.unlocked,
    this.unlockedAt,
  });

  final String id;
  final String title;
  final String description;
  final int current;
  final int target;
  final bool unlocked;
  final DateTime? unlockedAt;

  double get progress =>
      target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  factory TeamMilestoneModel.fromJson(Map<String, dynamic> json) =>
      TeamMilestoneModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        current: json['current'] as int? ?? 0,
        target: json['target'] as int? ?? 1,
        unlocked: json['unlocked'] as bool? ?? false,
        unlockedAt: json['unlocked_at'] != null
            ? DateTime.tryParse(json['unlocked_at'] as String)
            : null,
      );
}

class TeamMilestonesModel {
  const TeamMilestonesModel({required this.items});

  final List<TeamMilestoneModel> items;

  factory TeamMilestonesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TeamMilestonesModel(items: []);
    return TeamMilestonesModel(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => TeamMilestoneModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MemberModel {
  final String id;
  final String userId;
  final MemberRole role;
  final bool confirmedParticipation;
  final bool acceptedRules;
  final bool active;
  final int streak;
  final int bestStreak;
  final String reportStatus;
  final UserPublic? profile;

  MemberModel({
    required this.id,
    required this.userId,
    required this.role,
    required this.confirmedParticipation,
    required this.acceptedRules,
    required this.active,
    required this.streak,
    required this.bestStreak,
    required this.reportStatus,
    this.profile,
  });

  factory MemberModel.fromJson(Map<String, dynamic> j) => MemberModel(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        role: MemberRole.values.firstWhere(
          (e) => e.name == j['role'],
          orElse: () => MemberRole.member,
        ),
        confirmedParticipation: j['confirmed_participation'] as bool? ?? false,
        acceptedRules: j['accepted_rules'] as bool? ?? false,
        active: j['active'] as bool? ?? true,
        streak: j['streak'] as int? ?? 0,
        bestStreak: j['best_streak'] as int? ?? 0,
        reportStatus: j['report_status'] as String? ?? 'not_ready',
        profile: j['profile'] != null
            ? UserPublic.fromJson(j['profile'] as Map<String, dynamic>)
            : null,
      );
}

class GroupModel {
  final String id;
  final String name;
  final String skillId;
  final String? skillName;
  final GroupStatus status;
  final bool isPrivate;
  final String? inviteCode;
  final String? city;
  final String? regionCode;
  final String? regionName;
  final bool isCrossRegion;
  final int maxMembers;
  final String? matrixRoomId;
  final DateTime? cycleStartAt;
  final int membersCount;
  final List<MemberModel> members;
  final TeamPulseModel? teamPulse;
  final TeamDayModel? teamDay;
  final TeamRecapModel? teamRecap;
  final TeamMilestonesModel? teamMilestones;

  GroupModel({
    required this.id,
    required this.name,
    required this.skillId,
    this.skillName,
    required this.status,
    required this.isPrivate,
    this.inviteCode,
    this.city,
    this.regionCode,
    this.regionName,
    required this.isCrossRegion,
    required this.maxMembers,
    this.matrixRoomId,
    this.cycleStartAt,
    required this.membersCount,
    required this.members,
    this.teamPulse,
    this.teamDay,
    this.teamRecap,
    this.teamMilestones,
  });

  factory GroupModel.fromJson(Map<String, dynamic> j) => GroupModel(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        skillId: j['skill_id'] as String,
        skillName: j['skill_name'] as String?,
        status: _statusFromJson(j['status'] as String?),
        isPrivate: j['is_private'] as bool? ?? false,
        inviteCode: j['invite_code'] as String?,
        city: j['city'] as String?,
        regionCode: j['region_code'] as String?,
        regionName: j['region_name'] as String?,
        isCrossRegion: j['is_cross_region'] as bool? ?? false,
        maxMembers: j['max_members'] as int? ?? 6,
        matrixRoomId: j['matrix_room_id'] as String?,
        cycleStartAt: j['cycle_start_at'] != null
            ? DateTime.parse(j['cycle_start_at'] as String)
            : null,
        membersCount: j['members_count'] as int? ?? 0,
        members: (j['members'] as List<dynamic>? ?? [])
            .map((m) => MemberModel.fromJson(m as Map<String, dynamic>))
            .toList(),
        teamPulse: TeamPulseModel.fromJson(
          j['team_pulse'] as Map<String, dynamic>?,
        ),
        teamDay: j['team_day'] != null
            ? TeamDayModel.fromJson(j['team_day'] as Map<String, dynamic>)
            : null,
        teamRecap: j['team_recap'] != null
            ? TeamRecapModel.fromJson(j['team_recap'] as Map<String, dynamic>)
            : null,
        teamMilestones: j['team_milestones'] != null
            ? TeamMilestonesModel.fromJson(
                j['team_milestones'] as Map<String, dynamic>,
              )
            : null,
      );
}

GroupStatus _statusFromJson(String? value) {
  switch (value) {
    case 'introduction':
      return GroupStatus.introduction;
    case 'rules_pending':
      return GroupStatus.rulesPending;
    case 'active':
      return GroupStatus.active;
    case 'rotating':
      return GroupStatus.rotating;
    case 'voting':
      return GroupStatus.voting;
    case 'completed':
      return GroupStatus.completed;
    case 'forming':
    default:
      return GroupStatus.forming;
  }
}

class WaitingRoomSlot {
  const WaitingRoomSlot({
    required this.letter,
    this.regionCode,
    this.regionColorSeed = 0,
    this.joinedAgoSeconds = 0,
  });

  final String letter;
  final String? regionCode;
  final int regionColorSeed;
  final int joinedAgoSeconds;

  factory WaitingRoomSlot.fromJson(Map<String, dynamic> json) => WaitingRoomSlot(
        letter: json['letter'] as String? ?? '?',
        regionCode: json['region_code'] as String?,
        regionColorSeed: json['region_color_seed'] as int? ?? 0,
        joinedAgoSeconds: json['joined_ago_seconds'] as int? ?? 0,
      );
}

class WaitingRoomEvent {
  const WaitingRoomEvent({
    required this.type,
    required this.text,
    this.agoSeconds = 0,
  });

  final String type;
  final String text;
  final int agoSeconds;

  factory WaitingRoomEvent.fromJson(Map<String, dynamic> json) =>
      WaitingRoomEvent(
        type: json['type'] as String? ?? 'joined',
        text: json['text'] as String? ?? '',
        agoSeconds: json['ago_seconds'] as int? ?? 0,
      );
}

class WaitingRoomRegionStat {
  const WaitingRoomRegionStat({
    required this.code,
    required this.name,
    required this.count,
  });

  final String code;
  final String name;
  final int count;

  factory WaitingRoomRegionStat.fromJson(Map<String, dynamic> json) =>
      WaitingRoomRegionStat(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        count: json['count'] as int? ?? 0,
      );
}

class WaitingRoomStats {
  const WaitingRoomStats({
    this.regionCode,
    this.regionName,
    this.skillId,
    this.skillSearching = 0,
    this.regionSearching = 0,
    this.onlineInPool = 0,
    this.topRegions = const [],
    this.medianMatchHours,
  });

  final String? regionCode;
  final String? regionName;
  final String? skillId;
  final int skillSearching;
  final int regionSearching;
  final int onlineInPool;
  final List<WaitingRoomRegionStat> topRegions;
  final double? medianMatchHours;

  factory WaitingRoomStats.fromJson(Map<String, dynamic> json) =>
      WaitingRoomStats(
        regionCode: json['region_code'] as String?,
        regionName: json['region_name'] as String?,
        skillId: json['skill_id'] as String?,
        skillSearching: json['skill_searching'] as int? ?? 0,
        regionSearching: json['region_searching'] as int? ?? 0,
        onlineInPool: json['online_in_pool'] as int? ?? 0,
        topRegions: (json['top_regions'] as List<dynamic>? ?? [])
            .map((item) =>
                WaitingRoomRegionStat.fromJson(item as Map<String, dynamic>))
            .toList(),
        medianMatchHours: (json['median_match_hours'] as num?)?.toDouble(),
      );
}

class WaitingRoomStatus {
  final bool inQueue;
  final String? skillId;
  final String? skillName;
  final int peopleWaiting;
  final int needed;
  final int minMembers;
  final String? matchedGroupId;
  final String? regionCode;
  final String? regionName;
  final bool canExpandSearch;
  final bool allowOtherRegions;
  final DateTime? expansionAvailableAt;
  final DateTime? partialStartAvailableAt;
  final List<WaitingRoomStatus> queues;
  final List<WaitingRoomSlot> slots;
  final List<WaitingRoomEvent> events;
  final int onlineInPool;
  final int regionSearching;
  final int skillSearching;
  final double? medianMatchHours;

  WaitingRoomStatus({
    required this.inQueue,
    this.skillId,
    this.skillName,
    required this.peopleWaiting,
    required this.needed,
    this.minMembers = 3,
    this.matchedGroupId,
    this.regionCode,
    this.regionName,
    this.canExpandSearch = false,
    this.allowOtherRegions = false,
    this.expansionAvailableAt,
    this.partialStartAvailableAt,
    this.queues = const [],
    this.slots = const [],
    this.events = const [],
    this.onlineInPool = 0,
    this.regionSearching = 0,
    this.skillSearching = 0,
    this.medianMatchHours,
  });

  WaitingRoomStatus copyWith({
    List<WaitingRoomSlot>? slots,
    List<WaitingRoomEvent>? events,
    int? onlineInPool,
    int? regionSearching,
    int? skillSearching,
    double? medianMatchHours,
  }) =>
      WaitingRoomStatus(
        inQueue: inQueue,
        skillId: skillId,
        skillName: skillName,
        peopleWaiting: peopleWaiting,
        needed: needed,
        minMembers: minMembers,
        matchedGroupId: matchedGroupId,
        regionCode: regionCode,
        regionName: regionName,
        canExpandSearch: canExpandSearch,
        allowOtherRegions: allowOtherRegions,
        expansionAvailableAt: expansionAvailableAt,
        partialStartAvailableAt: partialStartAvailableAt,
        queues: queues,
        slots: slots ?? this.slots,
        events: events ?? this.events,
        onlineInPool: onlineInPool ?? this.onlineInPool,
        regionSearching: regionSearching ?? this.regionSearching,
        skillSearching: skillSearching ?? this.skillSearching,
        medianMatchHours: medianMatchHours ?? this.medianMatchHours,
      );

  factory WaitingRoomStatus.fromJson(Map<String, dynamic> j) =>
      WaitingRoomStatus(
        inQueue: j['in_queue'] as bool? ?? false,
        skillId: j['skill_id'] as String?,
        skillName: j['skill_name'] as String?,
        peopleWaiting: j['people_waiting'] as int? ?? 0,
        needed: j['needed'] as int? ?? 6,
        minMembers: j['min_members'] as int? ?? 3,
        matchedGroupId: j['matched_group_id'] as String?,
        regionCode: j['region_code'] as String?,
        regionName: j['region_name'] as String?,
        canExpandSearch: j['can_expand_search'] as bool? ?? false,
        allowOtherRegions: j['allow_other_regions'] as bool? ?? false,
        expansionAvailableAt: j['expansion_available_at'] != null
            ? DateTime.tryParse(j['expansion_available_at'] as String)
            : null,
        partialStartAvailableAt: j['partial_start_available_at'] != null
            ? DateTime.tryParse(j['partial_start_available_at'] as String)
            : null,
        queues: (j['queues'] as List<dynamic>? ?? [])
            .map((item) =>
                WaitingRoomStatus.fromJson(item as Map<String, dynamic>))
            .toList(),
        slots: (j['slots'] as List<dynamic>? ?? [])
            .map((item) =>
                WaitingRoomSlot.fromJson(item as Map<String, dynamic>))
            .toList(),
        events: (j['events'] as List<dynamic>? ?? [])
            .map((item) =>
                WaitingRoomEvent.fromJson(item as Map<String, dynamic>))
            .toList(),
        onlineInPool: j['online_in_pool'] as int? ?? 0,
        regionSearching: j['region_searching'] as int? ?? 0,
        skillSearching: j['skill_searching'] as int? ?? 0,
        medianMatchHours: (j['median_match_hours'] as num?)?.toDouble(),
      );
}

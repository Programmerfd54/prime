import 'dart:developer' as developer;

/// Typed analytics facade. Default sink logs in debug; no PII.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  AnalyticsSink _sink = const DebugAnalyticsSink();

  void setSink(AnalyticsSink sink) => _sink = sink;

  void track(AnalyticsEvent event) => _sink.track(event);

  void onboardingStarted() => track(const AnalyticsEvent('onboarding_started'));

  void onboardingAbandoned(int page, String stepId) => track(
        AnalyticsEvent('onboarding_abandoned', {
          'page': page,
          'step_id': stepId,
        }),
      );

  void onboardingView(int page) =>
      track(AnalyticsEvent('onboarding_view', {'page': page}));

  void onboardingStepViewed(int step, String stepId) => track(
        AnalyticsEvent('onboarding_step_viewed', {
          'step': step,
          'step_id': stepId,
        }),
      );

  void onboardingStepCompleted(int step) =>
      track(AnalyticsEvent('onboarding_step_completed', {'step': step}));

  void onboardingComplete({String? goal, String? skillId}) => track(
        AnalyticsEvent('onboarding_complete', {
          if (goal != null) 'goal': goal,
          if (skillId != null) 'skill_id': skillId,
        }),
      );

  void onboardingGoalSelected(String goal) =>
      track(AnalyticsEvent('onboarding_goal_selected', {'goal': goal}));

  void onboardingProgramSelected(String skillId) => track(
        AnalyticsEvent('onboarding_program_selected', {'skill_id': skillId}),
      );

  void onboardingSkip(int page) =>
      track(AnalyticsEvent('onboarding_skip', {'page': page}));

  void authStart({required bool register}) => track(
        AnalyticsEvent('auth_start', {'mode': register ? 'register' : 'login'}),
      );

  void authSuccess({required bool register}) => track(
        AnalyticsEvent('auth_success', {'mode': register ? 'register' : 'login'}),
      );

  void habitListViewed() => track(const AnalyticsEvent('habit_list_viewed'));

  void habitSaved(String skillId) =>
      track(AnalyticsEvent('habit_saved', {'skill_id': skillId}));

  void habitRecommendationViewed(String skillId) => track(
        AnalyticsEvent('habit_recommendation_viewed', {'skill_id': skillId}),
      );

  void habitPreviewCompleted(String skillId) => track(
        AnalyticsEvent('habit_preview_completed', {'skill_id': skillId}),
      );

  void habitCompareOpened(String skillId) =>
      track(AnalyticsEvent('habit_compare_opened', {'skill_id': skillId}));

  void registerStepViewed(int step) =>
      track(AnalyticsEvent('register_step_viewed', {'step': step}));

  void habitDetailsViewed(String skillId) =>
      track(AnalyticsEvent('habit_details_viewed', {'skill_id': skillId}));

  void searchStarted(String skillId) =>
      track(AnalyticsEvent('search_started', {'skill_id': skillId}));

  void teamReady(String groupId) =>
      track(AnalyticsEvent('team_ready', {'group_id': groupId}));

  void messageSendStarted({required String channel}) =>
      track(AnalyticsEvent('message_send_started', {'channel': channel}));

  void messageSendSuccess({required String channel}) =>
      track(AnalyticsEvent('message_send_success', {'channel': channel}));

  void messageSendFailed({required String channel, required String type}) =>
      track(AnalyticsEvent(
          'message_send_failed', {'channel': channel, 'type': type}));

  void errorRecovered({required String module, required String type}) =>
      track(AnalyticsEvent(
          'error_recovered', {'module': module, 'type': type}));

  void teamSearchConfigured({
    required String skillId,
    required bool allowOtherRegions,
  }) =>
      track(AnalyticsEvent('team_search_configured', {
        'skill_id': skillId,
        'allow_other_regions': allowOtherRegions,
      }));

  void teamJoinConfirmed(String groupId) => track(
        AnalyticsEvent('team_join_confirmed', {'group_id': groupId}),
      );

  void checkinStarted(String groupId) =>
      track(AnalyticsEvent('checkin_started', {'group_id': groupId}));

  void checkinCompleted(String groupId) =>
      track(AnalyticsEvent('checkin_completed', {'group_id': groupId}));

  void checkinEdited(String groupId) =>
      track(AnalyticsEvent('checkin_edited', {'group_id': groupId}));

  void chatAttachmentStarted({required String channel}) => track(
        AnalyticsEvent('chat_attachment_started', {'channel': channel}),
      );

  void chatAttachmentSucceeded({required String channel}) => track(
        AnalyticsEvent('chat_attachment_succeeded', {'channel': channel}),
      );

  void chatAttachmentFailed({required String channel, required String type}) =>
      track(AnalyticsEvent('chat_attachment_failed', {
        'channel': channel,
        'type': type,
      }));

  void insightOpened(String insightId) =>
      track(AnalyticsEvent('insight_opened', {'insight_id': insightId}));

  void cycleCompleted({String? groupId, String? skillId}) => track(
        AnalyticsEvent('cycle_completed', {
          if (groupId != null) 'group_id': groupId,
          if (skillId != null) 'skill_id': skillId,
        }),
      );
}

class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.props = const {}]);

  final String name;
  final Map<String, Object?> props;
}

abstract class AnalyticsSink {
  void track(AnalyticsEvent event);
}

class DebugAnalyticsSink implements AnalyticsSink {
  const DebugAnalyticsSink();

  @override
  void track(AnalyticsEvent event) {
    developer.log('${event.name} ${event.props}', name: 'analytics');
  }
}

class NoopAnalyticsSink implements AnalyticsSink {
  const NoopAnalyticsSink();

  @override
  void track(AnalyticsEvent event) {}
}

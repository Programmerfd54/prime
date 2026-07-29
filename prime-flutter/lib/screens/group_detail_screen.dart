import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics.dart';
import '../core/errors/failure_mapper.dart';
import '../core/pending/report_queue.dart';
import '../data/api_client.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../models/group.dart';
import '../models/report.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/editorial/app_group_editorial.dart';
import '../ui/components/editorial/app_weekly_team_challenge.dart';
import '../ui/components/editorial/app_group_pulse.dart';
import '../ui/components/editorial/app_group_recap.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_textarea.dart';
import '../ui/states/app_loading_state.dart';
import '../widgets/async_error_view.dart';
import 'group_chat_screen.dart';
import 'public_profile_screen.dart';

/// Детальная страница группы: участники, правила, голосование, отчёты.
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupModel? _group;
  CalendarDay? _todayReport;
  bool _loading = true;
  bool _actionInProgress = false;
  bool _checkInSending = false;
  String? _error;
  String? _errorCorrelationId;
  String? _actionWindow;
  bool _cycleCompletedEmitted = false;
  final _reportCtrl = TextEditingController();

  @override
  void dispose() {
    _reportCtrl.dispose();
    super.dispose();
  }

  bool _sendingReport = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _errorCorrelationId = null;
      });
    }
    final api = context.read<ApiClient>();
    unawaited(ReportQueue.instance.flush(api));
    try {
      final group = GroupModel.fromJson(await api.getGroup(widget.groupId));
      CalendarDay? todayReport;
      if (group.status == GroupStatus.active) {
        final calendar =
            CalendarOut.fromJson(await api.calendar(widget.groupId));
        for (final day in calendar.days) {
          if (_sameDate(day.date, calendar.today)) {
            todayReport = day;
            break;
          }
        }
      }
      _group = group;
      _todayReport = todayReport;
      if (group.status == GroupStatus.completed && !_cycleCompletedEmitted) {
        _cycleCompletedEmitted = true;
        Analytics.instance.cycleCompleted(
          groupId: group.id,
          skillId: group.skillId,
        );
      }
      try {
        final prefs = await api.getPreferences();
        _actionWindow = prefs['preferred_action_window'] as String?;
      } catch (_) {
        _actionWindow = null;
      }
    } catch (e) {
      if (mounted) {
        final failure = FailureMapper.from(e);
        _error = failure.message;
        _errorCorrelationId = failure.correlationId;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _confirm() async {
    await _runAction(
      () => context.read<ApiClient>().confirmParticipation(widget.groupId),
      onSuccess: () => Analytics.instance.teamJoinConfirmed(widget.groupId),
    );
  }

  Future<void> _acceptRules() async {
    await _runAction(
      () => context.read<ApiClient>().acceptRules(widget.groupId),
    );
  }

  Future<void> _changeGroup() async {
    await _runAction(
      () => context.read<ApiClient>().changeIntroGroup(widget.groupId),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _vote(String choice) async {
    await _runAction(
      () => context.read<ApiClient>().vote(widget.groupId, choice),
    );
  }

  Future<void> _checkIn(String kind) async {
    if (_checkInSending) return;
    setState(() => _checkInSending = true);
    try {
      await context.read<ApiClient>().groupCheckIn(widget.groupId, kind);
      await _load();
    } catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await ReportQueue.instance.enqueueCheckIn(
          groupId: widget.groupId,
          kind: kind,
        );
        if (mounted) {
          showAppSnackBar(context, 'Нет сети — отправим отметку при подключении');
        }
      } else if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _checkInSending = false);
    }
  }

  Future<void> _runAction(
    Future<Object?> Function() action, {
    VoidCallback? onSuccess,
  }) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await action();
      await _load();
      onSuccess?.call();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<bool> _sendReport(List<Map<String, dynamic>> attachments) async {
    final text = _reportCtrl.text.trim();
    if ((text.isEmpty && attachments.isEmpty) || _sendingReport) return false;
    final wasAlreadyReported = _todayReport?.reported == true;
    setState(() => _sendingReport = true);
    final api = context.read<ApiClient>();
    final reportPayload = {
      'group_id': widget.groupId,
      'content_text': text,
      'status': 'ready',
      'attachments': attachments,
      'support_given': false,
    };
    try {
      await api.createReport(reportPayload);
      _reportCtrl.clear();
      if (wasAlreadyReported) {
        Analytics.instance.checkinEdited(widget.groupId);
      } else {
        Analytics.instance.checkinCompleted(widget.groupId);
      }
      if (mounted) {
        showAppSnackBar(
          context,
          wasAlreadyReported ? 'Отчёт обновлён!' : 'Отчёт отправлен!',
        );
        await context.read<AuthProvider>().refreshUser();
        await _load();
      }
      return true;
    } catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await ReportQueue.instance.enqueueReport(reportPayload);
        _reportCtrl.clear();
        if (mounted) {
          showAppSnackBar(
            context,
            'Нет сети — отчёт сохранён и отправится при подключении',
          );
        }
        return true;
      }
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
      return false;
    } finally {
      if (mounted) setState(() => _sendingReport = false);
    }
  }

  Future<void> _showReportSheet() async {
    final existingReport = _todayReport;
    final editing = existingReport?.reported == true;
    _reportCtrl.text = editing ? existingReport?.contentText ?? '' : '';
    Analytics.instance.checkinStarted(widget.groupId);
    await showAppBottomSheet<void>(
      context: context,
      child: _ReportSheet(
        groupId: widget.groupId,
        controller: _reportCtrl,
        editing: editing,
        initialAttachments: editing
            ? existingReport?.attachments ?? const <Map<String, dynamic>>[]
            : const <Map<String, dynamic>>[],
        sending: _sendingReport,
        onSend: _sendReport,
      ),
    );
  }

  void _openChat(GroupModel group) {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => GroupChatScreen(
          groupId: group.id,
          groupName: group.skillName ?? group.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: buildAppBackBar(context, title: 'Группа'),
        body: const AppLoadingState(),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: buildAppBackBar(context, title: 'Группа'),
        body: AsyncErrorView(
          message: _error!,
          correlationId: _errorCorrelationId,
          onRetry: _load,
        ),
      );
    }
    final g = _group;
    if (g == null) {
      return Scaffold(
        appBar: buildAppBackBar(context, title: 'Группа'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
              fillOpacity: 0.05,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Группа не найдена',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSerif,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Возможно, ссылка устарела или доступ закрыт.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBackBar(context, title: g.name),
      body: AmbientCanvas(
        child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            AppGroupDetailHero(group: g),
            const SizedBox(height: AppSpacing.md),
            if (g.status == GroupStatus.introduction) ...[
              AppGroupIntroPanel(
                group: g,
                onOpenProfile: (member) {
                  final p = member.profile;
                  if (p == null) return;
                  Navigator.of(context).push(
                    PrimeRoute.sharedAxis(
                      builder: (_) => PublicProfileScreen(
                        profile: p,
                        reportStatus: member.reportStatus,
                        acceptedRules: member.acceptedRules,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppCopy.teamReadyConfirm,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppPrimaryButton(
                label: AppCopy.confirmParticipation,
                icon: Icons.check_circle_outline,
                loading: _actionInProgress,
                success: true,
                onPressed: _actionInProgress ? null : _confirm,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppSecondaryButton(
                label: 'Сменить группу',
                onPressed: _actionInProgress ? null : _changeGroup,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (g.status == GroupStatus.rulesPending) ...[
              const AppGroupRulesPanel(),
              const SizedBox(height: AppSpacing.sm),
              AppPrimaryButton(
                label: 'Принять правила',
                icon: Icons.verified_user_outlined,
                loading: _actionInProgress,
                onPressed: _actionInProgress ? null : _acceptRules,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (g.status == GroupStatus.active) ...[
              AppGroupDailyActions(
                reportSending: _sendingReport,
                reportAlreadySent: _todayReport?.reported == true,
                canOpenChat: g.matrixRoomId != null,
                onReport: _showReportSheet,
                onChat: () => _openChat(g),
              ),
              const SizedBox(height: AppSpacing.md),
              AppWeeklyTeamChallengeCard(group: g),
              const SizedBox(height: AppSpacing.md),
              if (g.teamPulse != null)
                AppGroupPulsePanel(
                  pulse: g.teamPulse!,
                  sending: _checkInSending,
                  onCheckIn: _checkIn,
                  actionWindow: _actionWindow,
                ),
              if (g.teamPulse != null) const SizedBox(height: AppSpacing.md),
              if (g.teamRecap != null) ...[
                AppGroupRecapPanel(recap: g.teamRecap!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (g.teamMilestones != null &&
                  g.teamMilestones!.items.isNotEmpty) ...[
                AppGroupMilestonesPanel(milestones: g.teamMilestones!),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
            if (g.status == GroupStatus.voting) ...[
              AppGroupVotingPanel(
                onContinueTogether: () => _vote('continue_together'),
                onNewSkill: () => _vote('new_skill'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              'Участники (${g.membersCount}/${g.maxMembers})',
              style: AppTypography.titleSerif,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...g.members.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppGroupMemberRow(
                  member: m,
                  onTap: m.profile == null
                      ? null
                      : () => Navigator.of(context).push(
                            PrimeRoute.sharedAxis(
                              builder: (_) => PublicProfileScreen(
                                profile: m.profile!,
                                reportStatus: m.reportStatus,
                                acceptedRules: m.acceptedRules,
                              ),
                            ),
                          ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final String groupId;
  final TextEditingController controller;
  final bool editing;
  final List<Map<String, dynamic>> initialAttachments;
  final bool sending;
  final Future<bool> Function(List<Map<String, dynamic>> attachments) onSend;

  const _ReportSheet({
    required this.groupId,
    required this.controller,
    required this.editing,
    required this.initialAttachments,
    required this.sending,
    required this.onSend,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  bool _hasText = false;
  bool _sending = false;
  bool _uploading = false;
  final _picker = ImagePicker();
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
    _attachments.addAll(
      widget.initialAttachments.map((item) => {...item, 'existing': true}),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) setState(() => _hasText = next);
  }

  Future<void> _send() async {
    if ((!_hasText && _attachments.isEmpty) ||
        _sending ||
        _uploading ||
        widget.sending) {
      return;
    }
    setState(() => _sending = true);
    final sent = await widget.onSend(List.unmodifiable(_attachments));
    if (mounted) setState(() => _sending = false);
    if (sent && mounted) Navigator.of(context).pop();
  }

  Future<void> _pick(String mediaType) async {
    if (kIsWeb && mediaType != 'image') {
      showAppSnackBar(
        context,
        'В web-версии отчёты пока можно отправлять текстом и фото',
      );
      return;
    }
    XFile? selected;
    if (mediaType == 'image') {
      selected = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
    } else if (mediaType == 'video') {
      selected = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      selected = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
    }
    if (selected == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final uploaded = await context
          .read<ApiClient>()
          .reportUploadMedia(widget.groupId, File(selected.path));
      if (mounted) {
        setState(() {
          _attachments.add({...uploaded, 'media_type': mediaType});
        });
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentSurface.withValues(alpha: 0.6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    Icons.edit_note,
                    color: AppColors.primarySoft,
                    size: AppIconSizes.sm,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.editing ? 'Поправить отчёт' : 'Отчёт за сегодня',
                    style: AppTypography.title2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextarea(
              controller: widget.controller,
              hint: 'Что ты сделал сегодня по этой привычке?',
              minLines: 4,
              maxLines: 7,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Фото',
                    icon: Icons.photo_outlined,
                    onPressed: _uploading ? null : () => _pick('image'),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Видео',
                      icon: Icons.videocam_outlined,
                      onPressed: _uploading ? null : () => _pick('video'),
                    ),
                  ),
                ],
              ],
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: AppSpacing.xs),
              AppSecondaryButton(
                label: 'Записать видеокружок',
                icon: Icons.circle_outlined,
                onPressed: _uploading ? null : () => _pick('video_note'),
              ),
            ],
            if (_uploading) ...[
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.elevatedSurface,
              ),
            ],
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: _attachments.asMap().entries.map((entry) {
                  final type = entry.value['media_type'];
                  return InputChip(
                    label: Text(
                      type == 'image'
                          ? 'Фото'
                          : type == 'video'
                              ? 'Видео'
                              : 'Видеокружок',
                      style: AppTypography.caption,
                    ),
                    onDeleted: _sending
                        ? null
                        : () => setState(
                              () => _attachments.removeAt(entry.key),
                            ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: _sending || widget.sending
                  ? 'Отправка...'
                  : widget.editing
                      ? 'Сохранить правку'
                      : 'Отправить отчёт',
              icon: Icons.send,
              loading: _sending || widget.sending,
              onPressed: (_hasText || _attachments.isNotEmpty) &&
                      !_sending &&
                      !_uploading &&
                      !widget.sending
                  ? _send
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

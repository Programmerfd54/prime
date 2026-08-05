import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../data/api_client.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/pressable.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/user.dart';
import '../../../ui/components/app_dropdown_field.dart';
import '../../../ui/components/app_search_field.dart';
import '../../../ui/components/app_secondary_button.dart';
import '../../../ui/components/app_snackbar.dart';
import '../../../ui/components/editorial/app_friend_search.dart';
import '../../../ui/components/profile/app_avatar.dart';
import '../../../ui/components/profile/verified_email_badge.dart';
import '../../../ui/kit/components/prime_content_card.dart';
import '../../../ui/kit/components/prime_empty_state.dart';
import '../../../ui/kit/tokens/kit_typography.dart';

class DiscoverUserItem {
  const DiscoverUserItem({
    required this.user,
    required this.isFriend,
    required this.hasPendingRequest,
    this.pendingRequestId,
    this.pendingDirection,
  });

  final UserPublic user;
  final bool isFriend;
  final bool hasPendingRequest;
  final String? pendingRequestId;
  final String? pendingDirection;

  factory DiscoverUserItem.fromJson(Map<String, dynamic> json) {
    return DiscoverUserItem(
      user: UserPublic.fromJson(json['user'] as Map<String, dynamic>),
      isFriend: json['is_friend'] as bool? ?? false,
      hasPendingRequest: json['has_pending_request'] as bool? ?? false,
      pendingRequestId: json['pending_request_id'] as String?,
      pendingDirection: json['pending_direction'] as String?,
    );
  }

  DiscoverUserItem copyWithRelation(Map<String, dynamic> patch) {
    final merged = {
      'user': {
        'id': user.id,
        'nickname': user.nickname,
        'name': user.name,
        'about': user.about,
        'photo_url': user.photoUrl,
        'city': user.city,
        'region_code': user.regionCode,
        'region_name': user.regionName,
        'age': user.age,
        'prime_points': user.primePoints,
        'successful_days': user.successfulDays,
        'email_verified': user.emailVerified,
        'privacy_settings': user.privacySettings,
      },
      'is_friend': isFriend,
      'has_pending_request': hasPendingRequest,
      'pending_request_id': pendingRequestId,
      'pending_direction': pendingDirection,
      ...patch,
    };
    return DiscoverUserItem.fromJson(merged);
  }
}

String discoverUserDisplayName(UserPublic user) {
  final name = user.name.trim();
  final nickname = user.nickname.trim();
  if (name.isNotEmpty && !name.contains('@')) return name;
  if (nickname.isNotEmpty) return '@$nickname';
  return name.isNotEmpty ? name : 'Участник';
}

bool matchesDiscoverQuery(DiscoverUserItem item, String query) =>
    _matchesDiscoverQuery(item, query);

bool _matchesDiscoverQuery(DiscoverUserItem item, String query) {
  final q = query.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
  if (q.length < 2) return true;
  final nick = item.user.nickname.toLowerCase();
  final name = item.user.name.toLowerCase();
  return nick.contains(q) || name.contains(q);
}

/// Browse verified users and send friend requests.
class UsersDiscoverPanel extends StatefulWidget {
  const UsersDiscoverPanel({
    super.key,
    this.onChanged,
    this.asSliverHost = false,
  });

  final VoidCallback? onChanged;

  /// When true, [build] returns a [SliverMainAxisGroup] for [CustomScrollView].
  final bool asSliverHost;

  @override
  State<UsersDiscoverPanel> createState() => _UsersDiscoverPanelState();
}

class _UsersDiscoverPanelState extends State<UsersDiscoverPanel> {
  static const _allRegionsValue = '__all__';

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _regions = [];
  String _regionFilter = _allRegionsValue;
  List<DiscoverUserItem> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _actionInFlight = false;
  String? _error;
  Map<String, dynamic>? _searchResult;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final regions = await context.read<ApiClient>().listRegions();
      if (mounted) setState(() => _regions = regions);
    } catch (_) {}
    await _loadDiscover(reset: true);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = _searchCtrl.text.trim();
      if (q.length >= 3) {
        _lookupNickname(q);
      } else {
        setState(() => _searchResult = null);
      }
      if (q.length >= 2) {
        setState(() {});
      }
    });
  }

  Future<void> _lookupNickname(String raw) async {
    final nickname = raw.trim().replaceFirst(RegExp(r'^@'), '');
    try {
      final found = await context.read<ApiClient>().findUserByNickname(nickname);
      if (mounted) setState(() => _searchResult = found);
    } catch (_) {
      if (mounted) setState(() => _searchResult = null);
    }
  }

  Future<void> _loadDiscover({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _nextCursor = null;
      });
    } else {
      if (_loadingMore || _nextCursor == null) return;
      setState(() => _loadingMore = true);
    }
    try {
      final api = context.read<ApiClient>();
      final regionCode =
          _regionFilter == _allRegionsValue ? null : _regionFilter;
      final raw = await api.discoverUsers(
        regionCode: regionCode,
        cursor: reset ? null : _nextCursor,
      );
      final page = (raw['items'] as List<dynamic>? ?? [])
          .map((e) => DiscoverUserItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = page;
        } else {
          _items = [..._items, ...page];
        }
        _nextCursor = raw['next_cursor'] as String?;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FailureMapper.from(e).message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _sendRequest(DiscoverUserItem item) async {
    if (_actionInFlight || item.user.nickname.isEmpty) return;
    setState(() => _actionInFlight = true);
    try {
      final result = await context
          .read<ApiClient>()
          .sendFriendRequestByNickname(item.user.nickname);
      if (!mounted) return;
      final patch = applyFriendRequestToLookup(
        {
          'user': {
            'id': item.user.id,
            'nickname': item.user.nickname,
            'name': item.user.name,
            'about': item.user.about,
            'photo_url': item.user.photoUrl,
            'region_name': item.user.regionName,
            'age': item.user.age,
            'email_verified': item.user.emailVerified,
          },
          'is_friend': item.isFriend,
          'has_pending_request': item.hasPendingRequest,
        },
        result,
      );
      _applyRelationPatch(item.user.id, patch);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  void _applyRelationPatch(String userId, Map<String, dynamic> patch) {
    setState(() {
      _items = _items
          .map(
            (row) => row.user.id == userId
                ? row.copyWithRelation(patch)
                : row,
          )
          .toList();
      if (_searchResult != null &&
          (_searchResult!['user'] as Map?)?['id'] == userId) {
        _searchResult = {..._searchResult!, ...patch};
      }
    });
  }

  String? get _searchResultUserId {
    final user = _searchResult?['user'];
    if (user is Map) return user['id'] as String?;
    return null;
  }

  List<DiscoverUserItem> get _visibleItems {
    final query = _searchCtrl.text.trim();
    final searchId = _searchResultUserId;
    return _items
        .where((item) {
          if (searchId != null && item.user.id == searchId) return false;
          return _matchesDiscoverQuery(item, query);
        })
        .toList();
  }

  List<DropdownMenuItem<String>> get _regionDropdownItems {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _allRegionsValue,
        child: Text('Вся Россия'),
      ),
    ];
    for (final region in _regions) {
      final code = region['code'] as String?;
      if (code == null || code.isEmpty) continue;
      items.add(
        DropdownMenuItem(
          value: code,
          child: Text(region['name'] as String? ?? code),
        ),
      );
    }
    return items;
  }

  Widget _buildHeaderSection() {
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.sm),
          child: Text(
            'Найдите людей по региону и добавьте в друзья',
            style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppSearchField(
            controller: _searchCtrl,
            label: 'Поиск по нику',
            hint: 'минимум 2 символа для фильтра',
            prefixText: '@',
            onSearch: () {
              final q = _searchCtrl.text.trim();
              if (q.length >= 3) _lookupNickname(q);
            },
          ),
        ),
        if (_searchResult != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DiscoverUserRow(
              item: DiscoverUserItem.fromJson(_searchResult!),
              busy: _actionInFlight,
              onAddFriend: () =>
                  _sendRequest(DiscoverUserItem.fromJson(_searchResult!)),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (_regions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppDropdownField<String>(
              value: _regionFilter,
              label: 'Регион',
              items: _regionDropdownItems,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _regionFilter = value);
                _loadDiscover(reset: true);
              },
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildListBody() {
    final p = context.prime;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: PrimeEmptyState(
          title: 'Не удалось загрузить',
          body: _error!,
          actionLabel: 'Повторить',
          onAction: () => _loadDiscover(reset: true),
        ),
      );
    }

    final visible = _visibleItems;
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: PrimeEmptyState(
          title: 'Пока никого нет',
          body: _searchCtrl.text.trim().length >= 2
              ? 'Никого не найдено — попробуйте другой запрос или регион.'
              : 'Попробуйте другой регион или поиск по никнейму.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Участники ПРАЙМ',
            style: KitTypography.sectionTitle.copyWith(color: p.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: _DiscoverUserRow(
              item: item,
              busy: _actionInFlight,
              onAddFriend: () => _sendRequest(item),
            ),
          ),
        if (_nextCursor != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppSecondaryButton(
              label: _loadingMore ? 'Загрузка…' : 'Показать ещё',
              onPressed: _loadingMore ? null : () => _loadDiscover(),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildSlivers() {
    final p = context.prime;
    final slivers = <Widget>[
      SliverToBoxAdapter(child: _buildHeaderSection()),
    ];

    if (_loading) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
      return slivers;
    }

    if (_error != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PrimeEmptyState(
              title: 'Не удалось загрузить',
              body: _error!,
              actionLabel: 'Повторить',
              onAction: () => _loadDiscover(reset: true),
            ),
          ),
        ),
      );
      return slivers;
    }

    final visible = _visibleItems;
    if (visible.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PrimeEmptyState(
              title: 'Пока никого нет',
              body: _searchCtrl.text.trim().length >= 2
                  ? 'Никого не найдено — попробуйте другой запрос или регион.'
                  : 'Попробуйте другой регион или поиск по никнейму.',
            ),
          ),
        ),
      );
      return slivers;
    }

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Участники ПРАЙМ',
            style: KitTypography.sectionTitle.copyWith(color: p.ink),
          ),
        ),
      ),
    );
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)));
    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= visible.length) return null;
            final item = visible[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: _DiscoverUserRow(
                item: item,
                busy: _actionInFlight,
                onAddFriend: () => _sendRequest(item),
              ),
            );
          },
          childCount: visible.length,
        ),
      ),
    );

    if (_nextCursor != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AppSecondaryButton(
              label: _loadingMore ? 'Загрузка…' : 'Показать ещё',
              onPressed: _loadingMore ? null : () => _loadDiscover(),
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSliverHost) {
      return SliverMainAxisGroup(slivers: _buildSlivers());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderSection(),
        _buildListBody(),
      ],
    );
  }
}

class _DiscoverUserRow extends StatelessWidget {
  const _DiscoverUserRow({
    required this.item,
    required this.busy,
    required this.onAddFriend,
  });

  final DiscoverUserItem item;
  final bool busy;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final user = item.user;
    final title = discoverUserDisplayName(user);
    final subtitle = [
      if (user.nickname.isNotEmpty) '@${user.nickname}',
      if (user.regionName?.isNotEmpty == true) user.regionName,
    ].join(' · ');

    Widget? action;
    if (item.isFriend) {
      action = Text('Друг', style: KitTypography.caption.copyWith(color: p.mint));
    } else if (item.hasPendingRequest) {
      action = Text(
        item.pendingDirection == 'incoming' ? 'Входящая' : 'Отправлено',
        style: KitTypography.caption.copyWith(color: p.inkMuted),
      );
    } else {
      action = _DiscoverAddButton(
        loading: busy,
        onPressed: busy ? null : onAddFriend,
      );
    }

    return PrimeContentCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppAvatar(
            name: title,
            photoUrl: user.photoUrl,
            radius: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VerifiedDisplayName(
                  name: title,
                  verified: user.emailVerified,
                  style: KitTypography.cardTitle.copyWith(
                    color: p.ink,
                    fontSize: 15,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: KitTypography.caption.copyWith(color: p.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          action,
        ],
      ),
    );
  }
}

class _DiscoverAddButton extends StatelessWidget {
  const _DiscoverAddButton({
    required this.loading,
    this.onPressed,
  });

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final enabled = onPressed != null && !loading;

    return PrimePressable(
      enabled: enabled,
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? p.brand : p.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? p.brand : p.hairline,
          ),
        ),
        child: loading
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: enabled ? Colors.white : p.inkMuted,
                ),
              )
            : Text(
                'Добавить',
                style: KitTypography.caption.copyWith(
                  color: enabled ? Colors.white : p.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

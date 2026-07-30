import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/models/chat_message.dart';
import 'package:prime/models/user.dart';
import 'package:prime/ui/components/chat/app_chat_message.dart';
import 'package:prime/ui/components/profile/app_avatar.dart';
import 'package:prime/ui/components/social/users_discover_panel.dart';

void main() {
  group('discoverUserDisplayName', () {
    test('prefers nickname when name looks like email', () {
      final user = UserPublic(
        id: '1',
        nickname: 'daniil123',
        name: 'dan@gmail.com',
        about: '',
      );
      expect(discoverUserDisplayName(user), '@daniil123');
    });

    test('uses nickname when name empty', () {
      final user = UserPublic(
        id: '1',
        nickname: 'wrightag',
        name: '',
        about: '',
      );
      expect(discoverUserDisplayName(user), '@wrightag');
    });

    test('uses display name when set', () {
      final user = UserPublic(
        id: '1',
        nickname: 'wrightag',
        name: 'Daniil',
        about: '',
      );
      expect(discoverUserDisplayName(user), 'Daniil');
    });
  });

  group('matchesDiscoverQuery', () {
    DiscoverUserItem item(String nick, String name) => DiscoverUserItem(
          user: UserPublic(id: '1', nickname: nick, name: name, about: ''),
          isFriend: false,
          hasPendingRequest: false,
        );

    test('matches nickname substring', () {
      expect(matchesDiscoverQuery(item('wrightag', 'Daniil'), 'wright'), isTrue);
    });

    test('returns true for short query', () {
      expect(matchesDiscoverQuery(item('abc', ''), 'a'), isTrue);
    });

    test('no match returns false', () {
      expect(matchesDiscoverQuery(item('abc', ''), 'xyz'), isFalse);
    });
  });

  testWidgets('AppChatMessage shows own avatar on outgoing last-in-group', (tester) async {
    const message = ChatMessageModel(
      id: 'm1',
      senderUserId: 'me',
      body: 'Привет',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: AppChatMessage(
            message: message,
            isMine: true,
            showAvatar: true,
            isLastInGroup: true,
            myAvatarUrl: null,
            myName: 'Me',
            timeLabel: '12:00',
          ),
        ),
      ),
    );

    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Привет'), findsOneWidget);
  });
}

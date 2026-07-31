import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/routes.dart';
import '../design/tokens.dart';
import '../providers/social_restriction_provider.dart';
import '../screens/moderation_appeal_screen.dart';
import 'social_restriction_banner.dart';

/// Restriction banner + appeal entry point for chat screens.
class SocialRestrictionChatPanel extends StatelessWidget {
  const SocialRestrictionChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final restriction = context.watch<SocialRestrictionProvider>();
    if (!restriction.isWriteBlocked || restriction.expiresAt == null) {
      return const SizedBox.shrink();
    }

    final decisionId = restriction.decisionId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SocialRestrictionBanner(expiresAt: restriction.expiresAt!),
          if (decisionId != null && decisionId.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PrimeRoute.sharedAxis(
                      builder: (_) => ModerationAppealScreen(
                        decisionId: decisionId,
                      ),
                    ),
                  );
                },
                child: const Text('Подать апелляцию'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

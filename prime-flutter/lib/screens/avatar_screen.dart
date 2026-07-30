import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/media/avatar_upload.dart';
import '../data/api_client.dart';
import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/profile/app_avatar.dart';
import '../ui/kit/components/prime_content_card.dart';
import '../ui/kit/presentation/profile_surfaces.dart';

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  double _progress = 0;
  String? _error;
  XFile? _previewFile;
  Uint8List? _previewBytes;

  Future<void> _showSourceSheet() async {
    final user = context.read<AuthProvider>().user;
    final hasPhoto = user?.photoUrl?.isNotEmpty == true;

    final action = await showAppBottomSheet<_AvatarAction>(
      context: context,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Фото профиля',
                  style: AppTypography.titleSerif,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Выбрать из галереи'),
                onTap: () => Navigator.pop(context, _AvatarAction.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Сделать фото'),
                onTap: () => Navigator.pop(context, _AvatarAction.camera),
              ),
              if (hasPhoto)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text(
                    'Удалить текущее фото',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () => Navigator.pop(context, _AvatarAction.delete),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _AvatarAction.gallery:
        await _pick(ImageSource.gallery);
      case _AvatarAction.camera:
        await _pick(ImageSource.camera);
      case _AvatarAction.delete:
        await _deleteAvatar();
    }
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _error = null;
      _previewFile = null;
      _previewBytes = null;
    });
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _previewFile = picked;
      _previewBytes = bytes;
    });
    await _upload(picked);
  }

  Future<void> _upload(XFile file) async {
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final payload = await prepareAvatarUpload(file);
      setState(() => _progress = 0.4);
      await context.read<AuthProvider>().uploadAvatarBytes(
            bytes: payload.bytes,
            filename: payload.filename,
            contentType: payload.contentType,
          );
      if (!mounted) return;
      setState(() {
        _previewFile = null;
        _previewBytes = null;
        _progress = 1;
      });
      showAppSnackBar(context, 'Аватар обновлён');
    } on AvatarUploadException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0;
        });
      }
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().deleteAvatar();
      if (!mounted) return;
      showAppSnackBar(context, 'Фото удалено');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: ProfileSurfaces.canvas,
      appBar: buildAppBackBar(context, title: 'Фото профиля'),
      body: AmbientCanvas(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: _uploading && _previewBytes != null
                  ? _LocalAvatarPreview(bytes: _previewBytes!, radius: 110)
                  : AppAvatar(
                      photoUrl: user?.photoUrl,
                      radius: 110,
                      name: user?.name ?? user?.nickname,
                      showEditBadge: !_uploading,
                      onTap: _uploading ? null : _showSourceSheet,
                    ),
            ),
            if (_uploading) ...[
              const SizedBox(height: AppSpacing.lg),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 3,
                backgroundColor: AppColors.primaryContainer,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Загрузка…',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppPrimaryButton(
                label: 'Повторить',
                onPressed: _previewFile == null
                    ? _showSourceSheet
                    : () => _upload(_previewFile!),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimeContentCard(
              child: Text(
                'Фото видно в чатах, группах и на главной',
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary.copyWith(
                  color: context.prime.inkSecondary,
                ),
              ),
            ),
            const Spacer(),
            AppPrimaryButton(
              label: 'Изменить фото',
              icon: Icons.photo_camera_outlined,
              loading: _uploading,
              onPressed: _uploading ? null : _showSourceSheet,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

enum _AvatarAction { gallery, camera, delete }

/// Optimistic local preview shown while the freshly-picked avatar uploads,
/// so the user sees their new photo instead of the stale network image.
class _LocalAvatarPreview extends StatelessWidget {
  const _LocalAvatarPreview({required this.bytes, required this.radius});

  final Uint8List bytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.borderStrong),
        image: DecorationImage(
          image: MemoryImage(bytes),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

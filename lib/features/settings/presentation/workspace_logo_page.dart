import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/auth_failure.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';

class WorkspaceLogoPage extends StatefulWidget {
  const WorkspaceLogoPage({super.key});

  @override
  State<WorkspaceLogoPage> createState() => _WorkspaceLogoPageState();
}

class _WorkspaceLogoPageState extends State<WorkspaceLogoPage> {
  bool _showOnForms = false;
  bool _saving = false;
  bool _hydrated = false;
  bool _removeExisting = false;
  Uint8List? _pickedBytes;
  String? _pickedContentType;
  String? _pickedExtension;
  String? _existingUrl;

  void _hydrateFromSession() {
    final org = context.read<AuthBloc>().state.session?.organization;
    if (org == null || _hydrated) return;
    _existingUrl = org.logoUrl;
    _showOnForms = org.showLogoOnForms;
    _hydrated = true;
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'svg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      showKaydoToast(
        context,
        message: "We couldn't read that file. Try another image.",
        tone: KaydoToastTone.error,
      );
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      if (!mounted) return;
      showKaydoToast(
        context,
        message: 'Logo must be 2 MB or smaller.',
        tone: KaydoToastTone.error,
      );
      return;
    }
    setState(() {
      _pickedBytes = bytes;
      _pickedExtension = file.extension;
      _pickedContentType = _mimeForExtension(file.extension);
      _removeExisting = false;
    });
  }

  String? _mimeForExtension(String? ext) {
    return switch (ext?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      _ => null,
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await getIt<AuthRepository>().updateWorkspaceLogo(
        imageBytes: _pickedBytes,
        contentType: _pickedContentType,
        fileExtension: _pickedExtension,
        showOnForms: _showOnForms,
        removeLogo: _removeExisting && _pickedBytes == null,
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthOrganizationUpdated(updated));
      setState(() {
        _existingUrl = updated.logoUrl;
        _pickedBytes = null;
        _pickedContentType = null;
        _pickedExtension = null;
        _removeExisting = false;
        _showOnForms = updated.showLogoOnForms;
      });
      showKaydoToast(
        context,
        message: 'Logo settings saved',
        tone: KaydoToastTone.success,
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      showKaydoToast(
        context,
        message: e.message,
        tone: KaydoToastTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      showKaydoToast(
        context,
        message: "We couldn't save your logo. Please try again.",
        tone: KaydoToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>().state.session;
    if (session == null || !session.profile.isAdmin) {
      return _messageGate(
        context,
        title: 'Only admins can change the workspace logo.',
        actionLabel: 'Back to dashboard',
        onAction: () => context.go('/dashboard'),
      );
    }

    if (!session.organization.plan.allowsWorkspaceLogo) {
      return _messageGate(
        context,
        title: 'Workspace logo is available on paid plans',
        body:
            'Upgrade to Starter or higher to upload your logo and show it on public feedback forms.',
        actionLabel: 'View plans',
        onAction: () => context.go('/settings/billing'),
      );
    }

    _hydrateFromSession();

    final theme = Theme.of(context);
    final hasPreview = _pickedBytes != null ||
        (!_removeExisting &&
            _existingUrl != null &&
            _existingUrl!.trim().isNotEmpty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
      children: [
        Text('Logo', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          'Upload your brand mark for public feedback forms.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: FelloColors.inkSoft,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: FelloColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FelloColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: FelloColors.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FelloColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildPreview(),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: Text(
                      hasPreview ? 'Replace image' : 'Upload image',
                    ),
                  ),
                  if (hasPreview)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _pickedBytes = null;
                                _pickedContentType = null;
                                _pickedExtension = null;
                                _removeExisting = true;
                                _showOnForms = false;
                              }),
                      style: TextButton.styleFrom(
                        foregroundColor: FelloColors.danger,
                      ),
                      child: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'PNG, JPG, WebP, or SVG · max 2 MB',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: FelloColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Show logo on public forms',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'When enabled, your logo appears at the top of /f/… pages.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: FelloColors.inkSoft,
                  ),
                ),
                value: _showOnForms,
                activeThumbColor: FelloColors.accent,
                onChanged: _saving || !hasPreview
                    ? null
                    : (v) => setState(() => _showOnForms = v),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    if (_pickedBytes != null) {
      return Image.memory(
        _pickedBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image_outlined,
          size: 36,
          color: FelloColors.inkSoft,
        ),
      );
    }
    if (!_removeExisting &&
        _existingUrl != null &&
        _existingUrl!.trim().isNotEmpty) {
      final url = _existingUrl!;
      if (url.startsWith('data:')) {
        final data = Uri.parse(url).data;
        if (data != null) {
          return Image.memory(
            Uint8List.fromList(data.contentAsBytes()),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: FelloColors.inkSoft,
            ),
          );
        }
      }
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image_outlined,
          size: 36,
          color: FelloColors.inkSoft,
        ),
      );
    }
    return const Icon(
      Icons.image_outlined,
      size: 36,
      color: FelloColors.accentDeep,
    );
  }

  Widget _messageGate(
    BuildContext context, {
    required String title,
    String? body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (body != null) ...[
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: FelloColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

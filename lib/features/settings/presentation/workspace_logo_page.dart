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
  const WorkspaceLogoPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<WorkspaceLogoPage> createState() => _WorkspaceLogoPageState();
}

class _WorkspaceLogoPageState extends State<WorkspaceLogoPage> {
  bool _saving = false;
  bool _hydrated = false;
  Uint8List? _pickedBytes;
  String? _pickedContentType;
  String? _pickedExtension;
  String? _existingUrl;

  void _hydrateFromSession() {
    final org = context.read<AuthBloc>().state.session?.organization;
    if (org == null || _hydrated) return;
    _existingUrl = org.logoUrl;
    _hydrated = true;
  }

  Future<void> _pickAndSave() async {
    if (_saving) return;
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
      _saving = true;
    });

    try {
      final updated = await getIt<AuthRepository>().updateWorkspaceLogo(
        imageBytes: bytes,
        contentType: _pickedContentType,
        fileExtension: _pickedExtension,
        showOnForms: true,
        removeLogo: false,
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthOrganizationUpdated(updated));
      setState(() {
        _existingUrl = updated.logoUrl;
        _pickedBytes = null;
        _pickedContentType = null;
        _pickedExtension = null;
      });
      showKaydoToast(
        context,
        message: 'Logo uploaded',
        tone: KaydoToastTone.success,
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      showKaydoToast(context, message: e.message, tone: KaydoToastTone.error);
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

  Future<void> _removeLogo() async {
    if (_saving || _existingUrl == null) return;
    setState(() => _saving = true);
    try {
      final updated = await getIt<AuthRepository>().updateWorkspaceLogo(
        showOnForms: false,
        removeLogo: true,
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthOrganizationUpdated(updated));
      setState(() => _existingUrl = null);
      showKaydoToast(
        context,
        message: 'Logo removed',
        tone: KaydoToastTone.success,
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      showKaydoToast(context, message: e.message, tone: KaydoToastTone.error);
    } catch (_) {
      if (!mounted) return;
      showKaydoToast(
        context,
        message: "We couldn't remove your logo. Please try again.",
        tone: KaydoToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        body: 'Upgrade to Starter or higher to upload your logo and show it on public feedback forms.',
        actionLabel: 'View plans',
        onAction: () => context.go('/settings/billing'),
      );
    }

    _hydrateFromSession();

    final theme = Theme.of(context);

    final editor = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _saving ? null : _pickAndSave,
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: FelloColors.border,
                  radius: 16,
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: _saving
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _buildContent(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.embedded) return _buildEmbeddedEditor(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Logo', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 24),
          Expanded(child: editor),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final preview = _buildPreview();
    if (preview != null) {
      return Column(
        children: [
          Expanded(child: preview),
          const SizedBox(height: 12),
          Text(
            'Tap to replace',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FelloColors.inkSoft,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: FelloColors.inkSoft,
        ),
        const SizedBox(height: 12),
        Text(
          'Upload image',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PNG, JPG, WebP, or SVG · max 2 MB',
          style: theme.textTheme.bodySmall?.copyWith(
            color: FelloColors.inkSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildEmbeddedEditor(ThemeData theme) {
    final hasLogo = _existingUrl != null && _existingUrl!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _pickAndSave,
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: FelloColors.border,
                radius: 12,
              ),
              child: SizedBox(
                height: 76,
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.upload_file_outlined,
                              size: 22,
                              color: FelloColors.inkSoft,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Click to upload logo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'PNG, JPG, WebP, or SVG · max 2 MB',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: FelloColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        if (hasLogo) ...[
          const SizedBox(height: 8),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FelloColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: _buildPreview(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Workspace logo',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove logo',
                  onPressed: _saving ? null : _removeLogo,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: FelloColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildPreview() {
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
    if (_existingUrl != null && _existingUrl!.trim().isNotEmpty) {
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
    return null;
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
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  static const double _strokeWidth = 1.5;
  static const double _dashLength = 7;
  static const double _gapLength = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset(_strokeWidth / 2, _strokeWidth / 2) &
          Size(size.width - _strokeWidth, size.height - _strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/kyc_service.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _picker = ImagePicker();

  File? _aadhaarFront;
  File? _aadhaarBack;
  File? _panCard;
  File? _selfie;

  bool _resubmitting = false;
  bool _submitting = false;
  String? _progress;
  String? _rejectionReason;

  bool get _allPicked =>
      _aadhaarFront != null &&
      _aadhaarBack != null &&
      _panCard != null &&
      _selfie != null;

  Future<void> _pickFor(String slot) async {
    final isSelfie = slot == 'selfie';
    ImageSource? source = ImageSource.camera;
    if (!isSelfie) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.accent),
                title: const Text('Take Photo',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.accent),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    if (source == null) return;

    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
      preferredCameraDevice:
          isSelfie ? CameraDevice.front : CameraDevice.rear,
    );
    if (picked == null) return;
    setState(() {
      final f = File(picked.path);
      switch (slot) {
        case 'aadhaar_front':
          _aadhaarFront = f;
        case 'aadhaar_back':
          _aadhaarBack = f;
        case 'pan_card':
          _panCard = f;
        case 'selfie':
          _selfie = f;
      }
    });
  }

  Future<void> _submit() async {
    final profile = ref.read(authProvider).valueOrNull;
    if (profile == null || !_allPicked) return;
    setState(() {
      _submitting = true;
      _progress = 'Uploading documents…';
    });

    try {
      final userId = profile.id;
      Future<String> up(String type, File f) =>
          KycService.uploadDocument(userId: userId, docType: type, file: f);

      // Sequential uploads keep memory low and give clear progress.
      setState(() => _progress = 'Uploading Aadhaar (front)…');
      final af = await up('aadhaar_front', _aadhaarFront!);
      setState(() => _progress = 'Uploading Aadhaar (back)…');
      final ab = await up('aadhaar_back', _aadhaarBack!);
      setState(() => _progress = 'Uploading PAN…');
      final pan = await up('pan_card', _panCard!);
      setState(() => _progress = 'Uploading selfie…');
      final selfie = await up('selfie', _selfie!);

      setState(() => _progress = 'Submitting for review…');
      await KycService.submitKyc(
        aadhaarFront: af,
        aadhaarBack: ab,
        panCard: pan,
        selfie: selfie,
      );

      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _submitting = false);
      _showDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _progress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${_friendly(e)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('upload_failed')) return 'a document upload failed';
    if (s.contains('already_approved')) return 'KYC already approved';
    return 'please try again';
  }

  void _showDone() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.accent, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Submitted!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Your documents are under review. This usually takes 24–48 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('DONE'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(authProvider);
    final status = profileAsync.valueOrNull?.kycStatus ?? 'pending';

    return Scaffold(
      appBar: AppBar(title: const Text('KYC VERIFICATION')),
      body: switch (status) {
        'approved' => _StatusView(
            icon: Icons.verified_rounded,
            color: AppColors.accent,
            title: 'KYC Verified',
            message: 'Your identity is verified. You can withdraw winnings.',
          ),
        'submitted' => _StatusView(
            icon: Icons.hourglass_top_rounded,
            color: AppColors.gold,
            title: 'Under Review',
            message:
                'We are reviewing your documents. This usually takes 24–48 hours.',
          ),
        'rejected' when !_resubmitting => _RejectedView(
            reason: _rejectionReason,
            onLoadReason: _loadRejectionReason,
            onResubmit: () => setState(() => _resubmitting = true),
          ),
        _ => _buildCaptureForm(),
      },
    );
  }

  Future<void> _loadRejectionReason() async {
    final reason = await KycService.fetchLatestRejectionReason();
    if (mounted && reason != null) setState(() => _rejectionReason = reason);
  }

  Widget _buildCaptureForm() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'Upload clear photos of your documents to enable withdrawals.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _DocSlot(
              label: 'Aadhaar Card — Front',
              file: _aadhaarFront,
              onTap: () => _pickFor('aadhaar_front'),
            ),
            _DocSlot(
              label: 'Aadhaar Card — Back',
              file: _aadhaarBack,
              onTap: () => _pickFor('aadhaar_back'),
            ),
            _DocSlot(
              label: 'PAN Card',
              file: _panCard,
              onTap: () => _pickFor('pan_card'),
            ),
            _DocSlot(
              label: 'Selfie (front camera)',
              file: _selfie,
              icon: Icons.face_outlined,
              onTap: () => _pickFor('selfie'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Documents are stored securely and used only for identity '
                      'verification.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: ElevatedButton(
            onPressed: (_allPicked && !_submitting) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              disabledBackgroundColor: AppColors.muted.withValues(alpha: 0.3),
            ),
            child: Text(_allPicked
                ? 'SUBMIT FOR VERIFICATION'
                : 'ADD ALL 4 DOCUMENTS'),
          ),
        ),
        if (_submitting)
          Container(
            color: Colors.black.withValues(alpha: 0.65),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    _progress ?? 'Working…',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Document slot ─────────────────────────────────────────────────────────────

class _DocSlot extends StatelessWidget {
  final String label;
  final File? file;
  final IconData icon;
  final VoidCallback onTap;

  const _DocSlot({
    required this.label,
    required this.file,
    required this.onTap,
    this.icon = Icons.badge_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final done = file != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? AppColors.accent : AppColors.muted,
              width: done ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: done
                    ? Image.file(file!,
                        width: 56, height: 56, fit: BoxFit.cover)
                    : Container(
                        width: 56,
                        height: 56,
                        color: AppColors.surface,
                        child: Icon(icon, color: AppColors.muted),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                done ? Icons.check_circle : Icons.add_circle_outline,
                color: done ? AppColors.accent : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status views ──────────────────────────────────────────────────────────────

class _StatusView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _StatusView({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _RejectedView extends StatefulWidget {
  final String? reason;
  final Future<void> Function() onLoadReason;
  final VoidCallback onResubmit;

  const _RejectedView({
    required this.reason,
    required this.onLoadReason,
    required this.onResubmit,
  });

  @override
  State<_RejectedView> createState() => _RejectedViewState();
}

class _RejectedViewState extends State<_RejectedView> {
  @override
  void initState() {
    super.initState();
    if (widget.reason == null) widget.onLoadReason();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: AppColors.danger, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('KYC Rejected',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              widget.reason ?? 'Your documents could not be verified.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onResubmit,
                child: const Text('RESUBMIT DOCUMENTS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

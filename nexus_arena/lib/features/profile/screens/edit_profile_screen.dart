import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _uidCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _uidCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  void _prefill(Profile p) {
    if (_prefilled) return;
    _nameCtrl.text = p.displayName;
    if (p.gameUid != null) _uidCtrl.text = p.gameUid!;
    if (p.upiId != null) _upiCtrl.text = p.upiId!;
    _prefilled = true;
  }

  Future<void> _save(Profile profile) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name cannot be empty'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ProfileService.updateProfile(
        userId: profile.id,
        displayName: name,
        gameUid: _uidCtrl.text.trim().isEmpty ? null : _uidCtrl.text.trim(),
        upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
      );
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.card,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(authProvider);
    final profile = profileAsync.valueOrNull;

    if (profile != null) _prefill(profile);

    final locked = profile != null && !profile.canEditProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('EDIT PROFILE')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              if (locked) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined,
                          color: AppColors.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Profile can be edited again on '
                          '${DateFormat('dd MMM, hh:mm a').format(profile.nextEditAllowedAt)}',
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                controller: _nameCtrl,
                enabled: !locked && !_saving,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Your in-game name',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _uidCtrl,
                enabled: !locked && !_saving,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Free Fire UID',
                  hintText: '12-digit game UID',
                  prefixIcon:
                      Icon(Icons.gamepad_outlined, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _upiCtrl,
                enabled: !locked && !_saving,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'name@bank',
                  prefixIcon:
                      Icon(Icons.account_balance_outlined, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'UPI ID is used for withdrawals — changes take effect immediately.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: (!locked && !_saving && profile != null)
                  ? () => _save(profile)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.muted.withValues(alpha: 0.3),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.background),
                    )
                  : Text(locked ? 'PROFILE LOCKED' : 'SAVE CHANGES'),
            ),
          ),
        ],
      ),
    );
  }
}

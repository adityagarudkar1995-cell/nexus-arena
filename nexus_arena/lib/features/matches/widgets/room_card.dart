import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';

class RoomCard extends StatelessWidget {
  final String roomId;
  final String roomPassword;

  const RoomCard({
    super.key,
    required this.roomId,
    required this.roomPassword,
  });

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        children: [
          _Field(
            label: 'ROOM ID',
            value: roomId,
            onCopy: () => _copy(context, roomId, 'Room ID'),
          ),
          const Divider(color: AppColors.card, height: 1),
          _Field(
            label: 'PASSWORD',
            value: roomPassword,
            onCopy: () => _copy(context, roomPassword, 'Password'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _Field({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 22),
            color: AppColors.accent,
            tooltip: 'Copy $label',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

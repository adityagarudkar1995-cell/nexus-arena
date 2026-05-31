import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Self-managing countdown that ticks to [target].
/// When [target] is reached it shows [expiredLabel].
class LobbyCountdown extends StatefulWidget {
  final DateTime target;
  final String headerLabel;
  final String expiredLabel;

  const LobbyCountdown({
    super.key,
    required this.target,
    this.headerLabel = 'OPENS IN',
    this.expiredLabel = 'Room is opening...',
  });

  @override
  State<LobbyCountdown> createState() => _LobbyCountdownState();
}

class _LobbyCountdownState extends State<LobbyCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final diff = widget.target.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    if (diff.isNegative) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return Text(
        widget.expiredLabel,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }

    final h = _pad(_remaining.inHours);
    final m = _pad(_remaining.inMinutes % 60);
    final s = _pad(_remaining.inSeconds % 60);

    return Column(
      children: [
        Text(
          widget.headerLabel,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Block(h, 'HRS'),
            _Sep(),
            _Block(m, 'MIN'),
            _Sep(),
            _Block(s, 'SEC'),
          ],
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final String value;
  final String unit;
  const _Block(this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(unit,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20, left: 6, right: 6),
      child: Text(
        ':',
        style: TextStyle(
            color: AppColors.accent,
            fontSize: 30,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

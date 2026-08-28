import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'app_toast.dart';
import 'ble_service.dart';

/// "Daily Protocol" screen — matches the Stitch "exercises" mockup: a
/// prescribed exercise card (Start button) followed by completed/pending
/// cards. Tapping Start opens a countdown timer (same timer logic as the
/// previous build), and finishing marks that card complete.
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final List<_ExerciseItem> _items = [
    _ExerciseItem(
      name: 'Toe Standing',
      description: 'Strengthen calf muscles and improve balance. Hold for 5 seconds per rep.',
      sets: 3,
      reps: 10,
    ),
    _ExerciseItem(
      name: 'Heel-to-Toe Walking',
      description: 'Enhance proprioception and gait stability. Walk in a straight line.',
      durationLabel: '5m',
      done: true,
    ),
    _ExerciseItem(
      name: 'Single-Leg Balance',
      description: 'Improve stability and proprioceptive control on each side.',
      sets: 3,
      reps: 8,
    ),
    _ExerciseItem(
      name: 'Calf Raises',
      description: 'Build ankle strength to support a steadier push-off phase.',
      sets: 3,
      reps: 15,
    ),
  ];

  Future<void> _startExercise(_ExerciseItem item) async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => _TimerSheet(item: item),
    );
    if (completed == true) {
      setState(() => item.done = true);
      if (mounted) showAppToast(context, '${item.name} complete');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: AppColors.green, size: 18),
                const SizedBox(width: 8),
                Text('InSoul', style: AppFonts.headline(fontSize: 16, color: AppColors.green)),
                const Spacer(),
                Consumer<BleService>(
                  builder: (context, ble, _) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ble.connected ? AppColors.green : AppColors.textDim,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ble.connected ? 'Sensor Active' : 'Sensor Idle',
                          style: AppFonts.body(fontSize: 11, color: AppColors.textMid, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Daily Protocol', style: AppFonts.headline(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Complete your prescribed routines to track your recovery progress.',
              style: AppFonts.body(fontSize: 13, color: AppColors.textMid),
            ),
            const SizedBox(height: 20),
            ...List.generate(_items.length, (i) {
              final it = _items[i];
              // "Next up" = first not-yet-done item, i.e. every item before
              // it is already done.
              final isNextUp = !it.done && _items.sublist(0, i).every((e) => e.done);
              return _ExerciseCard(
                item: it,
                highlighted: isNextUp,
                onStart: () => _startExercise(it),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ExerciseItem {
  final String name;
  final String description;
  final int? sets;
  final int? reps;
  final String? durationLabel;
  bool done;

  _ExerciseItem({
    required this.name,
    required this.description,
    this.sets,
    this.reps,
    this.durationLabel,
    this.done = false,
  });
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseItem item;
  final bool highlighted;
  final VoidCallback onStart;

  const _ExerciseCard({required this.item, required this.highlighted, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final bg = item.done ? AppColors.surfaceHighest.withValues(alpha: 0.6) : AppColors.surface;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted ? AppColors.green.withValues(alpha: 0.5) : AppColors.borderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.done ? AppColors.surfaceHighest : AppColors.greenDim,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.directions_walk,
                  color: item.done ? AppColors.textDim : AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppFonts.headline(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.done ? AppColors.surfaceHi : AppColors.greenDim,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.done ? 'COMPLETED' : 'PRESCRIBED',
                        style: AppFonts.label(fontSize: 10, color: item.done ? AppColors.textDim : AppColors.green),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.done) const Icon(Icons.check_circle, color: AppColors.green, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.description,
            style: AppFonts.body(fontSize: 13, color: AppColors.textMid, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.durationLabel != null) ...[
                _StatBlock(label: 'DURATION', value: item.durationLabel!),
              ] else ...[
                _StatBlock(label: 'SETS', value: '${item.sets}'),
                const SizedBox(width: 24),
                _StatBlock(label: 'REPS', value: '${item.reps}'),
              ],
              const Spacer(),
              item.done
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDim,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: Text('DONE', style: AppFonts.label(fontSize: 11)),
                    )
                  : ElevatedButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text('START', style: AppFonts.label(fontSize: 11, color: AppColors.onGreen)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenBright,
                        foregroundColor: AppColors.onGreen,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        elevation: 0,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppFonts.label(fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: AppFonts.metric(fontSize: 20)),
      ],
    );
  }
}

class _TimerSheet extends StatefulWidget {
  final _ExerciseItem item;
  const _TimerSheet({required this.item});

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  bool _running = false;
  int _seconds = 45;
  Timer? _timer;

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 0) {
        t.cancel();
        setState(() => _running = false);
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _seconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.item.name, style: AppFonts.headline(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Text(
            '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
            style: AppFonts.metric(fontSize: 48),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _toggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _running ? AppColors.surfaceHi : AppColors.greenBright,
                  foregroundColor: _running ? AppColors.text : AppColors.onGreen,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  elevation: 0,
                ),
                child: Text(_running ? 'Pause' : 'Start', style: AppFonts.label(fontSize: 13)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDim,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
                child: Text('Close', style: AppFonts.label(fontSize: 13, color: AppColors.textDim)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

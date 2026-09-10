import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'app_toast.dart';
import 'ble_service.dart';
import 'calf_raises_minigame.dart';

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
      description:
          'Enhance proprioception and gait stability. Walk in a straight line.',
      durationLabel: '5m',
      done: true,
    ),
    _ExerciseItem(
      name: 'Single-Leg Balance',
      description: 'Improve stability and proprioceptive control on each side.',
      sets: 2,
      reps: 4,
    ),
    _ExerciseItem(
      name: 'Calf Raises',
      description: 'Build ankle strength to support a steadier push-off phase.',
      sets: 3,
      reps: 5,
    ),
  ];

  Future<bool> _startExercise(_ExerciseItem item) async {
    final lowerName = item.name.toLowerCase();
    final isToeStanding = lowerName == 'toe standing';
    final isSingleLegBalance =
        lowerName.contains('single') && lowerName.contains('leg');
    final isCalfRaises = lowerName == 'calf raises';
    final completed = await (isCalfRaises
        ? showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => CalfRaisesMinigame(
              targetReps: item.reps ?? 1,
            ),
          )
        : isToeStanding || isSingleLegBalance
        ? showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => isToeStanding
                ? _ToeStandingTimerSheet(item: item)
                : _SingleLegStandingTimerSheet(item: item),
          )
        : showModalBottomSheet<bool>(
            context: context,
            backgroundColor: AppColors.surface,
            isDismissible: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            builder: (ctx) => _TimerSheet(item: item),
          ));
    if (completed == true) {
      await _showRestBreak();
      if (!mounted) return true;
      setState(() => item.done = true);
      context.read<BleService>().recordExerciseCompleted(item.name);
      if (mounted) showAppToast(context, '${item.name} complete');
      return true;
    }
    return false;
  }

  Future<void> _showRestBreak() async {
    await _showRestBreakDialog(context);
  }

  Future<void> _startAutoplay() async {
    if (!mounted) return;
    for (final item in _items) {
      if (!mounted) return;
      await _startExercise(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedExerciseNames =
        context.watch<BleService>().completedExerciseNames;
    for (final item in _items) {
      if (completedExerciseNames.contains(item.name)) {
        item.done = true;
      }
    }

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
                Text(
                  'InSoul',
                  style: AppFonts.headline(
                    fontSize: 16,
                    color: AppColors.green,
                  ),
                ),
                const Spacer(),
                Consumer<BleService>(
                  builder: (context, ble, _) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
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
                            color: ble.connected
                                ? AppColors.green
                                : AppColors.textDim,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ble.connected ? 'Sensor Active' : 'Sensor Idle',
                          style: AppFonts.body(
                            fontSize: 11,
                            color: AppColors.textMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Daily Protocol',
              style: AppFonts.headline(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete your prescribed routines to track your recovery progress.',
              style: AppFonts.description(
                fontSize: 13,
                color: AppColors.textMid,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startAutoplay,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(
                  'AUTOPLAY ALL EXERCISES',
                  style: AppFonts.label(
                    fontSize: 12,
                    color: AppColors.onGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenBright,
                  foregroundColor: AppColors.onGreen,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(_items.length, (i) {
              final it = _items[i];
              // "Next up" = first not-yet-done item, i.e. every item before
              // it is already done.
              final isNextUp =
                  !it.done && _items.sublist(0, i).every((e) => e.done);
              return _ExerciseCard(
                item: it,
                highlighted: isNextUp,
                onStart: () => _startExercise(it),
                onRetry: () => _startExercise(it),
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

Future<void> _showRestBreakDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RestBreakDialog(),
  );
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseItem item;
  final bool highlighted;
  final VoidCallback onStart;
  final VoidCallback onRetry;

  const _ExerciseCard({
    required this.item,
    required this.highlighted,
    required this.onStart,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bg = item.done
        ? AppColors.surfaceHighest.withValues(alpha: 0.6)
        : AppColors.surface;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted
              ? AppColors.green.withValues(alpha: 0.5)
              : AppColors.borderSoft,
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
                  color: item.done
                      ? AppColors.surfaceHighest
                      : AppColors.greenDim,
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
                    Text(
                      item.name,
                      style: AppFonts.headline(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.done
                            ? AppColors.surfaceHi
                            : AppColors.greenDim,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.done ? 'COMPLETED' : 'PRESCRIBED',
                        style: AppFonts.label(
                          fontSize: 10,
                          color: item.done
                              ? AppColors.textDim
                              : AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.done)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.green,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.description,
            style: AppFonts.description(
              fontSize: 13,
              color: AppColors.textMid,
              height: 1.4,
            ),
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
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: onRetry,
                          tooltip: 'Retry exercise',
                          icon: const Icon(Icons.refresh, size: 19),
                          color: AppColors.green,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDim,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: Text('DONE', style: AppFonts.label(fontSize: 11)),
                        ),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text(
                        'START',
                        style: AppFonts.label(
                          fontSize: 11,
                          color: AppColors.onGreen,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenBright,
                        foregroundColor: AppColors.onGreen,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
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

class _SingleLegStandingTimerSheet extends StatefulWidget {
  final _ExerciseItem item;
  const _SingleLegStandingTimerSheet({required this.item});

  @override
  State<_SingleLegStandingTimerSheet> createState() =>
      _SingleLegStandingTimerSheetState();
}

class _SingleLegStandingTimerSheetState extends State<_SingleLegStandingTimerSheet>
    with TickerProviderStateMixin {
  static const int _maxSeconds = 10;
  static const Duration _tick = Duration(milliseconds: 200);
  static const List<String> _legSequence = ['L', 'L', 'R', 'R'];

  late final BleService _ble;
  Timer? _timer;
  DateTime? _countingStartedAt;
  int _elapsedSeconds = 0;
  int _accumulatedSeconds = 0;
  bool _counting = false;
  bool _isCompleted = false;
  bool _wasGood = false;
  int _currentRep = 1;
  final int _totalReps = 4;
  final AudioPlayer _goodSound = AudioPlayer();
  late AnimationController _fadeController;

  String get _currentLegLabel => _legSequence[_currentRep - 1];
  String get _currentRepLabel =>
      _currentLegLabel == 'L' ? 'Left leg' : 'Right leg';

  @override
  void initState() {
    super.initState();
    _ble = context.read<BleService>();
    _ble.addListener(_handleBleState);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _handleBleState() {
    if (!mounted) return;

    final currentLeg = _currentLegLabel;
    final singleLegActive = _ble.singleLegLoad;
    final isCorrectLeg = singleLegActive == currentLeg;

    if (isCorrectLeg && !_wasGood) {
      _playGoodSound();
    }
    _wasGood = isCorrectLeg;

    if (isCorrectLeg && !_counting && _elapsedSeconds < _maxSeconds) {
      _startOrResumeTimer();
    } else if ((!isCorrectLeg || singleLegActive == null) && _counting) {
      _pauseTimer();
    }
  }

  Future<void> _playGoodSound() async {
    await _goodSound.stop();
    await _goodSound.play(AssetSource('Audio/correct sound.mp3'));
  }

  void _startOrResumeTimer() {
    if (_counting) return;
    setState(() => _counting = true);
    _countingStartedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted || _countingStartedAt == null) return;

      final elapsed =
          _accumulatedSeconds +
          DateTime.now().difference(_countingStartedAt!).inSeconds;
      if (elapsed >= _maxSeconds) {
        _accumulatedSeconds = _maxSeconds;
        _elapsedSeconds = _maxSeconds;
        _countingStartedAt = null;
        _counting = false;
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _isCompleted = true;
          });
          _fadeController.forward().then((_) async {
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            await _fadeController.reverse();
            if (!mounted) return;
            if (_currentRep < _totalReps) {
              await _showRestBreakDialog(context);
              if (!mounted) return;
              setState(() {
                _isCompleted = false;
                _currentRep++;
                _elapsedSeconds = 0;
                _accumulatedSeconds = 0;
              });
            } else {
              Navigator.of(context).pop(true);
            }
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _elapsedSeconds = elapsed);
      }
    });
  }

  void _pauseTimer() {
    if (!_counting || _countingStartedAt == null) return;
    _accumulatedSeconds += DateTime.now()
        .difference(_countingStartedAt!)
        .inSeconds;
    _countingStartedAt = null;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _counting = false;
      _elapsedSeconds = _accumulatedSeconds;
    });
  }

  @override
  void dispose() {
    _ble.removeListener(_handleBleState);
    _timer?.cancel();
    _goodSound.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = _elapsedSeconds;
    final visibleSeconds = totalSeconds <= _maxSeconds ? totalSeconds : _maxSeconds;
    final overtimeSeconds = totalSeconds > _maxSeconds ? totalSeconds - _maxSeconds : 0;
    final isActive = _counting;

    return Focus(
      onKeyEvent: (node, event) {
        final sensor = switch (event.logicalKey) {
          LogicalKeyboardKey.keyY => ('L', 'toe'),
          LogicalKeyboardKey.keyH => ('L', 'heel'),
          LogicalKeyboardKey.keyJ => ('R', 'heel'),
          LogicalKeyboardKey.keyU => ('R', 'toe'),
          _ => null,
        };
        if (sensor != null) {
          _ble.debugSimulateSensorInput(
            sensor.$1,
            sensor.$2,
            event is KeyDownEvent,
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      autofocus: true,
      child: _buildDialog(visibleSeconds, overtimeSeconds, isActive),
    );
  }

  Widget _buildDialog(int visibleSeconds, int overtimeSeconds, bool isActive) {
    if (_isCompleted) {
      return Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: FadeTransition(
          opacity: _fadeController,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DONE!',
                  style: AppFonts.metric(
                    fontSize: 85,
                    color: AppColors.greenBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_currentRep < _totalReps)
                  Text(
                    'Rep $_currentRep of $_totalReps',
                    style: AppFonts.body(
                      fontSize: 14,
                      color: AppColors.textMid,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Single-Leg Balance - $_currentRepLabel · Rep ${_currentRep <= 2 ? _currentRep : _currentRep - 2}/2',
              style: AppFonts.headline(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isActive ? 'good!' : 'Get in form!',
              style: AppFonts.body(
                fontSize: 13,
                color: isActive ? AppColors.greenBright : AppColors.amber,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
              child: Image.asset(
                'assets/images/Single leg standing .png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$visibleSeconds',
                  style: AppFonts.metric(
                    fontSize: 92,
                    color: overtimeSeconds > 0
                        ? AppColors.amber
                        : AppColors.greenBright,
                    letterSpacing: -2.0,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  's',
                  style: AppFonts.body(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
            if (overtimeSeconds > 0) ...[
              const SizedBox(height: 8),
              Text(
                '+${overtimeSeconds}s',
                style: AppFonts.label(
                  fontSize: 18,
                  color: AppColors.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceHi,
                  foregroundColor: AppColors.text,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Close',
                  style: AppFonts.label(fontSize: 13, color: AppColors.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToeStandingTimerSheet extends StatefulWidget {
  final _ExerciseItem item;
  const _ToeStandingTimerSheet({required this.item});

  @override
  State<_ToeStandingTimerSheet> createState() => _ToeStandingTimerSheetState();
}

class _ToeStandingTimerSheetState extends State<_ToeStandingTimerSheet>
    with TickerProviderStateMixin {
  static const int _maxSeconds = 10; // Back to 10 seconds per rep
  static const Duration _tick = Duration(milliseconds: 200);

  late final BleService _ble;
  Timer? _timer;
  DateTime? _countingStartedAt;
  int _elapsedSeconds = 0;
  int _accumulatedSeconds = 0;
  bool _counting = false;
  bool _isCompleted = false;
  bool _wasGood = false;
  int _currentRep = 1;
  final int _totalReps = 3;
  final AudioPlayer _goodSound = AudioPlayer();
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _ble = context.read<BleService>();
    _ble.addListener(_handleBleState);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _handleBleState() {
    if (!mounted) return;

    final toeStanding = _ble.toeStandingActive;
    if (toeStanding && !_wasGood) {
      _playGoodSound();
    }
    _wasGood = toeStanding;
    if (toeStanding && !_counting && _elapsedSeconds < _maxSeconds) {
      _startOrResumeTimer();
    } else if (!toeStanding && _counting) {
      _pauseTimer();
    }
  }

  Future<void> _playGoodSound() async {
    await _goodSound.stop();
    await _goodSound.play(AssetSource('Audio/correct sound.mp3'));
  }

  void _startOrResumeTimer() {
    if (_counting) return;
    setState(() => _counting = true);
    _countingStartedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted || _countingStartedAt == null) return;

      final elapsed =
          _accumulatedSeconds +
          DateTime.now().difference(_countingStartedAt!).inSeconds;
      if (elapsed >= _maxSeconds) {
        _accumulatedSeconds = _maxSeconds;
        _elapsedSeconds = _maxSeconds;
        _countingStartedAt = null;
        _counting = false;
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _isCompleted = true;
          });
          _fadeController.forward().then((_) async {
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            await _fadeController.reverse();
            if (!mounted) return;
            if (_currentRep < _totalReps) {
              await _showRestBreakDialog(context);
              if (!mounted) return;
              setState(() {
                _isCompleted = false;
                _currentRep++;
                _elapsedSeconds = 0;
                _accumulatedSeconds = 0;
              });
            } else {
              Navigator.of(context).pop(true);
            }
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _elapsedSeconds = elapsed);
      }
    });
  }

  void _pauseTimer() {
    if (!_counting || _countingStartedAt == null) return;
    _accumulatedSeconds += DateTime.now()
        .difference(_countingStartedAt!)
        .inSeconds;
    _countingStartedAt = null;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _counting = false;
      _elapsedSeconds = _accumulatedSeconds;
    });
  }

  @override
  void dispose() {
    _ble.removeListener(_handleBleState);
    _timer?.cancel();
    _goodSound.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = _elapsedSeconds;
    final visibleSeconds = totalSeconds <= _maxSeconds
        ? totalSeconds
        : _maxSeconds;
    final overtimeSeconds = totalSeconds > _maxSeconds
        ? totalSeconds - _maxSeconds
        : 0;
    final isActive = _counting;

    return Focus(
      onKeyEvent: (node, event) {
        final sensor = switch (event.logicalKey) {
          LogicalKeyboardKey.keyY => ('L', 'toe'),
          LogicalKeyboardKey.keyH => ('L', 'heel'),
          LogicalKeyboardKey.keyJ => ('R', 'heel'),
          LogicalKeyboardKey.keyU => ('R', 'toe'),
          _ => null,
        };
        if (sensor != null) {
          _ble.debugSimulateSensorInput(
            sensor.$1,
            sensor.$2,
            event is KeyDownEvent,
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      autofocus: true,
      child: _buildDialog(visibleSeconds, overtimeSeconds, isActive),
    );
  }

  Widget _buildDialog(int visibleSeconds, int overtimeSeconds, bool isActive) {
    if (_isCompleted) {
      return Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: FadeTransition(
          opacity: _fadeController,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DONE!',
                  style: AppFonts.metric(
                    fontSize: 85,
                    color: AppColors.greenBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_currentRep < _totalReps)
                  Text(
                    'Rep $_currentRep of $_totalReps',
                    style: AppFonts.body(
                      fontSize: 14,
                      color: AppColors.textMid,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Toe Standing - Rep $_currentRep/$_totalReps',
              style: AppFonts.headline(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isActive ? 'good!' : 'Get in form!',
              style: AppFonts.body(
                fontSize: 13,
                color: isActive ? AppColors.greenBright : AppColors.amber,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
              child: Image.asset(
                'assets/images/Toe Standing.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$visibleSeconds',
                  style: AppFonts.metric(
                    fontSize: 92,
                    color: overtimeSeconds > 0
                        ? AppColors.amber
                        : AppColors.greenBright,
                    letterSpacing: -2.0,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  's',
                  style: AppFonts.body(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
            if (overtimeSeconds > 0) ...[
              const SizedBox(height: 8),
              Text(
                '+${overtimeSeconds}s',
                style: AppFonts.label(
                  fontSize: 18,
                  color: AppColors.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceHi,
                  foregroundColor: AppColors.text,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Close',
                  style: AppFonts.label(fontSize: 13, color: AppColors.text),
                ),
              ),
            ),
          ],
        ),
      ),
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
  static const int _targetHoldSeconds = 5;

  bool _armed = false;
  bool _running = false;
  Duration _elapsed = Duration.zero;
  Duration _accumulated = Duration.zero;
  DateTime? _startedAt;
  Timer? _ticker;
  late final BleService _ble;

  @override
  void initState() {
    super.initState();
    _ble = context.read<BleService>();
    _ble.addListener(_handleBleState);
    _handleBleState();
  }

  bool get _isSingleLegExercise {
    final name = widget.item.name.toLowerCase();
    return name.contains('single') && name.contains('leg');
  }

  void _handleBleState() {
    if (!mounted || !_armed) return;

    final pressureActive = _ble.pressureDetected;
    final singleLegActive =
        _ble.singleLegLoad == 'L' || _ble.singleLegLoad == 'R';

    if (_isSingleLegExercise) {
      if (singleLegActive && !_running) {
        _startLocalStopwatch();
      } else if (!singleLegActive && _running) {
        _pauseLocalStopwatch();
      }
      return;
    }

    if (pressureActive && !_running) {
      _startLocalStopwatch();
    } else if (!pressureActive && _running) {
      _pauseLocalStopwatch();
    }
  }

  void _startLocalStopwatch() {
    if (_running) return;
    setState(() => _running = true);
    _startedAt = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _startedAt == null) return;

      final now = DateTime.now();
      final runningElapsed = _accumulated + now.difference(_startedAt!);
      if (runningElapsed.inSeconds >= _targetHoldSeconds) {
        _pauseLocalStopwatch();
        setState(() => _elapsed = Duration(seconds: _targetHoldSeconds));
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      setState(() => _elapsed = runningElapsed);
    });
  }

  void _pauseLocalStopwatch() {
    if (!_running || _startedAt == null) return;

    _accumulated += DateTime.now().difference(_startedAt!);
    _startedAt = null;
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _running = false;
      _elapsed = _accumulated;
    });
  }

  void _onPrimaryPressed() {
    _armed = true;
    _elapsed = Duration.zero;
    _accumulated = Duration.zero;
    _startedAt = null;
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    setState(() {});

    final singleLegActive =
        _ble.singleLegLoad == 'L' || _ble.singleLegLoad == 'R';
    if (_isSingleLegExercise ? singleLegActive : _ble.pressureDetected) {
      _startLocalStopwatch();
    }
  }

  @override
  void dispose() {
    _ble.removeListener(_handleBleState);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressureActive = context.select<BleService, bool>(
      (ble) => ble.pressureDetected,
    );
    final hasStarted = _armed;
    final statusText = !hasStarted
        ? 'Step onto the sensor to begin'
        : _running
        ? 'Timing active'
        : pressureActive
        ? 'Ready to resume'
        : 'Paused — keep pressure on the sensor';
    final minutes = (_elapsed.inSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final tenths = (_elapsed.inMilliseconds % 1000 ~/ 100).toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.item.name,
            style: AppFonts.headline(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: AppFonts.body(
              fontSize: 12,
              color: AppColors.textMid,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$minutes:$seconds.$tenths',
            style: AppFonts.metric(fontSize: 48),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _running
                      ? AppColors.surfaceHi
                      : AppColors.greenBright,
                  foregroundColor: _running
                      ? AppColors.text
                      : AppColors.onGreen,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  !hasStarted
                      ? 'Start'
                      : _running
                      ? 'Pause'
                      : 'Resume',
                  style: AppFonts.label(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDim,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  'Close',
                  style: AppFonts.label(fontSize: 13, color: AppColors.textDim),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestBreakDialog extends StatefulWidget {
  const _RestBreakDialog();

  @override
  State<_RestBreakDialog> createState() => _RestBreakDialogState();
}

class _RestBreakDialogState extends State<_RestBreakDialog> {
  static const int _restDurationSeconds = 30;
  Timer? _timer;
  int _remainingSeconds = _restDurationSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Rest break',
        style: AppFonts.headline(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Recover before the next set or exercise.',
            textAlign: TextAlign.center,
            style: AppFonts.body(fontSize: 13, color: AppColors.textMid),
          ),
          const SizedBox(height: 20),
          Text(
            '$_remainingSeconds',
            style: AppFonts.metric(fontSize: 64, color: AppColors.greenBright),
          ),
          Text(
            'seconds',
            style: AppFonts.label(fontSize: 11, color: AppColors.textDim),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              _timer?.cancel();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.skip_next, size: 18),
            label: Text(
              'SKIP REST',
              style: AppFonts.label(fontSize: 12, color: AppColors.green),
            ),
          ),
        ),
      ],
    );
  }
}

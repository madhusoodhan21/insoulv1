import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'app_toast.dart';
import 'home_screen.dart';
import 'exercise_screen.dart';
import 'physio_screen.dart';
import 'profile_screen.dart';
import 'ble_service.dart';
import 'gait_analysis_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;
  late final PageController _pageController;

  final _pages = const [
    ExerciseScreen(),
    PhysioScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    HardwareKeyboard.instance.addHandler(_handleDebugKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleDebugKeyEvent);
    _pageController.dispose();
    super.dispose();
  }

  bool _handleDebugKeyEvent(KeyEvent event) {
    final ble = Provider.of<BleService>(context, listen: false);
    if (ble.connected) return false;

    final sensor = switch (event.logicalKey) {
      LogicalKeyboardKey.keyJ => ('R', 'heel'),
      LogicalKeyboardKey.keyU => ('R', 'toe'),
      LogicalKeyboardKey.keyY => ('L', 'toe'),
      LogicalKeyboardKey.keyH => ('L', 'heel'),
      _ => null,
    };
    if (sensor == null) return false;

    if (event is KeyDownEvent) {
      ble.debugSimulateSensorInput(sensor.$1, sensor.$2, true);
    } else if (event is KeyUpEvent) {
      ble.debugSimulateSensorInput(sensor.$1, sensor.$2, false);
    }
    return true;
  }

  void goTo(int index) {
    if (index == _index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openNewActivitySheet() async {
    final result = await showModalBottomSheet<_NewActivityResult>(
      context: context,
      backgroundColor: AppColors.surfaceHi,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => const _NewActivitySheet(),
    );
    if (result != null) {
      if (!mounted) return;
      showAppToast(
        context,
        '${result.activity} logged · ${result.minutes} min',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _index = index),
        children: [
          HomeScreen(
            onOpenExercise: () => goTo(1),
            onOpenProfile: () => goTo(3),
            onOpenGaitAnalysis: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GaitAnalysisScreen()),
            ),
          ),
          _pages[0],
          _pages[1],
          _pages[2],
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onSelect: goTo,
        onFab: _openNewActivitySheet,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onFab;

  const _BottomNav({
    required this.index,
    required this.onSelect,
    required this.onFab,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.only(
              top: 10,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
              left: 8,
              right: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceHi.withValues(alpha: 0.7),
              border: Border.all(color: AppColors.borderSoft, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bg.withValues(alpha: 0.38),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: index == 0,
                  onTap: () => onSelect(0),
                ),
                _NavItem(
                  icon: Icons.fitness_center,
                  label: 'Exercise',
                  active: index == 1,
                  onTap: () => onSelect(1),
                ),
                _FabItem(onTap: onFab),
                _NavItem(
                  icon: Icons.insights,
                  label: 'Physio',
                  active: index == 2,
                  onTap: () => onSelect(2),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  active: index == 3,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.onGreen : AppColors.textDim;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: active
              ? AppColors.green.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
            color: active
                ? AppColors.green.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppFonts.body(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabItem extends StatelessWidget {
  final VoidCallback onTap;
  const _FabItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.greenBright,
          border: Border.all(color: AppColors.surfaceHi, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: AppColors.onGreen, size: 24),
      ),
    );
  }
}

class _NewActivityResult {
  final String activity;
  final int minutes;
  _NewActivityResult(this.activity, this.minutes);
}

/// "Create New Activity" sheet — matches the Stitch "new_activity" mockup:
/// activity type chips, a duration slider, an activity-goal callout, and a
/// primary "Create Task" button.
class _NewActivitySheet extends StatefulWidget {
  const _NewActivitySheet();

  @override
  State<_NewActivitySheet> createState() => _NewActivitySheetState();
}

class _NewActivitySheetState extends State<_NewActivitySheet> {
  int _activityIndex = 0;
  final _activities = const [
    (label: 'Walking', icon: Icons.directions_walk),
    (label: 'Running', icon: Icons.directions_run),
    (label: 'Exercise', icon: Icons.fitness_center),
  ];
  double _minutes = 10;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Create New Activity',
                    style: AppFonts.headline(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceHighest,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('SELECT ACTIVITY', style: AppFonts.label(fontSize: 11)),
            const SizedBox(height: 10),
            Row(
              children: List.generate(_activities.length, (i) {
                final a = _activities[i];
                final active = i == _activityIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activityIndex = i),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: i == _activities.length - 1 ? 0 : 10,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? AppColors.green
                              : AppColors.borderSoft,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            a.icon,
                            color: active ? AppColors.green : AppColors.textMid,
                            size: 22,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            a.label,
                            style: AppFonts.body(
                              fontSize: 12,
                              color: active
                                  ? AppColors.green
                                  : AppColors.textMid,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            Text('SET DURATION', style: AppFonts.label(fontSize: 11)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_minutes.round()}',
                          style: AppFonts.metric(
                            fontSize: 30,
                            color: AppColors.green,
                          ),
                        ),
                        TextSpan(
                          text: ' mins',
                          style: AppFonts.body(
                            fontSize: 15,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.green,
                      inactiveTrackColor: AppColors.surfaceHighest,
                      thumbColor: AppColors.green,
                      overlayColor: AppColors.green.withValues(alpha: 0.2),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _minutes,
                      min: 5,
                      max: 60,
                      onChanged: (v) => setState(() => _minutes = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '5m',
                        style: AppFonts.body(
                          fontSize: 11,
                          color: AppColors.textDim,
                        ),
                      ),
                      Text(
                        '60m',
                        style: AppFonts.body(
                          fontSize: 11,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenDim,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Goal',
                    style: AppFonts.headline(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Maintain a steady cadence for ${_minutes.round()} minutes to accurately record baseline gait symmetry.',
                    style: AppFonts.body(
                      fontSize: 12.5,
                      color: AppColors.textMid,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  _NewActivityResult(
                    _activities[_activityIndex].label,
                    _minutes.round(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenBright,
                  foregroundColor: AppColors.onGreen,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create Task',
                      style: AppFonts.label(
                        fontSize: 14,
                        color: AppColors.onGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

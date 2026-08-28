import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'app_toast.dart';
import 'ble_service.dart';

/// Physio tab — folds together the Stitch "physio_analysis" (live pressure
/// map / current pattern / session log) and "weekly_insights" (steps /
/// distance / gait / pressure trend chips) mockups behind a Live/Weekly
/// toggle, since both live under the same bottom-nav "Physio" tab.
class PhysioScreen extends StatefulWidget {
  const PhysioScreen({super.key});

  @override
  State<PhysioScreen> createState() => _PhysioScreenState();
}

class _PhysioScreenState extends State<PhysioScreen> {
  int _mode = 0; // 0 Live, 1 Weekly

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
                  builder: (context, ble, _) => Row(
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
                      Text(ble.connected ? 'Active' : 'Idle', style: AppFonts.body(fontSize: 12, color: AppColors.textMid)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(label: 'PHYSIO ANALYSIS', active: _mode == 0, onTap: () => setState(() => _mode = 0)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(label: 'WEEKLY INSIGHTS', active: _mode == 1, onTap: () => setState(() => _mode = 1)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_mode == 0) const _LivePhysioView() else const _WeeklyInsightsView(),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppColors.greenBright : AppColors.surfaceHi,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppFonts.label(fontSize: 10.5, color: active ? AppColors.onGreen : AppColors.textDim),
        ),
      ),
    );
  }
}

class _LivePhysioView extends StatelessWidget {
  const _LivePhysioView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Physio Analysis', style: AppFonts.headline(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Real-time gait and pressure monitoring.', style: AppFonts.body(fontSize: 13, color: AppColors.textMid)),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Pressure Map', style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _FootPressure(label: 'Left', topColor: AppColors.green, bottomColor: AppColors.amber),
                  _FootPressure(label: 'Right', topColor: AppColors.green, bottomColor: AppColors.red),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('CURRENT PATTERN', style: AppFonts.label(fontSize: 11)),
                  const Spacer(),
                  const Icon(Icons.check_circle, color: AppColors.green, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text('Normal', style: AppFonts.metric(fontSize: 30, color: AppColors.green)),
              const SizedBox(height: 6),
              Text(
                'Slight pronation detected on right foot. Within acceptable variance.',
                style: AppFonts.body(fontSize: 12.5, color: AppColors.textMid, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('STRIDE LENGTH', style: AppFonts.label(fontSize: 11)),
                  const Spacer(),
                  const Icon(Icons.straighten, size: 16, color: AppColors.textDim),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: '72', style: AppFonts.metric(fontSize: 30)),
                    TextSpan(text: ' cm', style: AppFonts.body(fontSize: 15, color: AppColors.textDim)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(height: 6, child: Container(color: AppColors.surfaceHighest, child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.72, child: Container(color: AppColors.green)))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Session Log', style: AppFonts.headline(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => showAppToast(context, 'Preparing export…'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      side: const BorderSide(color: AppColors.green),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: Text('Export Data', style: AppFonts.label(fontSize: 10, color: AppColors.green)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _LogHeaderRow(),
              const Divider(color: AppColors.borderSoft, height: 20),
              _LogRow(time: '10:45:22', l: '42 kPa', r: '45 kPa', ok: true),
              _LogRow(time: '10:46:05', l: '41 kPa', r: '48 kPa', ok: true),
              _LogRow(time: '10:48:12', l: '55 kPa', r: '30 kPa', ok: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _FootPressure extends StatelessWidget {
  final String label;
  final Color topColor;
  final Color bottomColor;
  const _FootPressure({required this.label, required this.topColor, required this.bottomColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(45),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor.withValues(alpha: 0.5), Colors.transparent, bottomColor.withValues(alpha: 0.4)],
            ),
            border: Border.all(color: AppColors.borderSoft),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.accessibility_new, color: Colors.white54, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppFonts.body(fontSize: 12, color: AppColors.textMid, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LogHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text('TIME', style: AppFonts.label(fontSize: 10))),
        Expanded(flex: 3, child: Text('AVG (L)', style: AppFonts.label(fontSize: 10))),
        Expanded(flex: 3, child: Text('AVG (R)', style: AppFonts.label(fontSize: 10))),
        Expanded(flex: 2, child: Text('STATUS', style: AppFonts.label(fontSize: 10))),
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  final String time;
  final String l;
  final String r;
  final bool ok;
  const _LogRow({required this.time, required this.l, required this.r, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(time, style: AppFonts.body(fontSize: 12.5))),
          Expanded(flex: 3, child: Text(l, style: AppFonts.body(fontSize: 12.5))),
          Expanded(flex: 3, child: Text(r, style: AppFonts.body(fontSize: 12.5))),
          Expanded(
            flex: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? AppColors.green : AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyInsightsView extends StatefulWidget {
  const _WeeklyInsightsView();

  @override
  State<_WeeklyInsightsView> createState() => _WeeklyInsightsViewState();
}

class _WeeklyInsightsViewState extends State<_WeeklyInsightsView> {
  int _tab = 0; // Steps, Distance, Gait, Pressure
  final _tabs = const ['STEPS', 'DISTANCE', 'GAIT', 'PRESSURE'];
  final _weekly = const [4200.0, 6800.0, 5900.0, 7100.0, 6600.0, 8300.0, 4120.0];
  final _days = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final maxVal = _weekly.reduce((a, b) => a > b ? a : b);
    final total = _weekly.fold<double>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly Analysis', style: AppFonts.headline(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('This week · 7-day rolling window', style: AppFonts.body(fontSize: 13, color: AppColors.textMid)),
        const SizedBox(height: 16),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final active = i == _tab;
              return GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: active ? AppColors.greenBright : AppColors.surfaceHi,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(_tabs[i], style: AppFonts.label(fontSize: 11, color: active ? AppColors.onGreen : AppColors.textDim)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Total ${_tabs[_tab].toLowerCase()}', style: AppFonts.headline(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(20)),
                    child: Text('+12%', style: AppFonts.body(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(total.round().toString(), style: AppFonts.metric(fontSize: 30)),
              const SizedBox(height: 20),
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_weekly.length, (i) {
                    final h = (_weekly[i] / maxVal) * 90;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: i == _weekly.length - 2 ? AppColors.green : AppColors.surfaceHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: _days.map((d) => Expanded(child: Center(child: Text(d, style: AppFonts.body(fontSize: 11, color: AppColors.textDim))))).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.textDim),
                        const SizedBox(width: 6),
                        Text('AVG STANCE TIME', style: AppFonts.label(fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('0.62', style: AppFonts.metric(fontSize: 26)),
                    Text('seconds / step', style: AppFonts.body(fontSize: 11, color: AppColors.textDim)),
                  ],
                ),
              ),
              const Icon(Icons.show_chart, color: AppColors.green, size: 40),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('L/R BALANCE', style: AppFonts.label(fontSize: 10)),
                    const SizedBox(height: 8),
                    Text('50 / 50', style: AppFonts.metric(fontSize: 22)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(20)),
                child: Text('Optimal', style: AppFonts.body(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'ble_service.dart';

/// Live MPU6050 gyroscope readout.
class AccelerometerScreen extends StatelessWidget {
  const AccelerometerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final hasData = ble.gyroscopeX != null ||
      ble.gyroscopeY != null ||
      ble.gyroscopeZ != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Gyroscope', style: AppFonts.headline(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ble.connected ? AppColors.greenDim : AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ble.connected ? AppColors.green : AppColors.textDim,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ble.connected ? 'MPU6050 streaming' : 'Not connected',
                          style: AppFonts.body(fontSize: 11.5, color: ble.connected ? AppColors.green : AppColors.textDim, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Live angular velocity data streamed from the ESP32\'s MPU6050 '
                'gyroscope over the same BLE characteristic as the step count.',
                style: AppFonts.body(fontSize: 13, color: AppColors.textMid, height: 1.4),
              ),
              const SizedBox(height: 24),
              Text('GYROSCOPE (°/s)', style: AppFonts.label(fontSize: 11)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _AxisCard(axis: 'X', value: ble.gyroscopeX, color: AppColors.red)),
                  const SizedBox(width: 10),
                  Expanded(child: _AxisCard(axis: 'Y', value: ble.gyroscopeY, color: AppColors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _AxisCard(axis: 'Z', value: ble.gyroscopeZ, color: AppColors.sky)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'Packets received', value: '${ble.packetCount}'),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Last packet',
                      value: ble.lastPacketAt == null
                          ? '—'
                          : '${DateTime.now().difference(ble.lastPacketAt!).inSeconds}s ago',
                    ),
                  ],
                ),
              ),
              if (!hasData) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.amberDim,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    ble.connected
                        ? 'Connected, but no IMU data yet — make sure the firmware is publishing the "imu": {"ax","ay","az","gx","gy","gz"} fields in its JSON packet.'
                        : 'Connect to your InSoul shoe from the Home screen to see live gyroscope values here.',
                    style: AppFonts.body(fontSize: 12.5, color: AppColors.amber, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AxisCard extends StatelessWidget {
  final String axis;
  final double? value;
  final Color color;
  const _AxisCard({required this.axis, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Text(axis, style: AppFonts.label(fontSize: 12, color: color)),
          const SizedBox(height: 8),
          Text(
            value == null ? '—' : value!.toStringAsFixed(2),
            style: AppFonts.metric(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppFonts.body(fontSize: 12.5, color: AppColors.textMid)),
        Text(value, style: AppFonts.body(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

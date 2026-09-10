import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'ble_service.dart';

class SerialMonitorScreen extends StatelessWidget {
  const SerialMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Serial Monitor',
          style: AppFonts.headline(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear output',
            onPressed: ble.debugSerialLines.isEmpty
                ? null
                : ble.clearDebugSerialLines,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.keyboard, color: AppColors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keyboard and controller emulation are active while no shoe is connected. Right stick X/Y sends GX/GY.',
                      style: AppFonts.description(
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ),
                  Text(
                    '${ble.debugSerialLines.length} packets',
                    style: AppFonts.label(fontSize: 10, color: AppColors.green),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _KeyHint(keyLabel: 'Y', label: 'Left toe'),
                  _KeyHint(keyLabel: 'H', label: 'Left heel'),
                  _KeyHint(keyLabel: 'J', label: 'Right heel'),
                  _KeyHint(keyLabel: 'U', label: 'Right toe'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: ble.debugSerialLines.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Waiting for keyboard or controller input...',
                          style: AppFonts.body(
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: ble.debugSerialLines.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SelectableText(
                            ble.debugSerialLines[ble.debugSerialLines.length -
                                1 -
                                index],
                            style: AppFonts.body(
                              fontSize: 11,
                              color: AppColors.green,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String keyLabel;
  final String label;

  const _KeyHint({required this.keyLabel, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.greenDim,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
          ),
          child: Text(
            keyLabel,
            style: AppFonts.headline(fontSize: 13, color: AppColors.green),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppFonts.body(fontSize: 9, color: AppColors.textDim),
        ),
      ],
    );
  }
}

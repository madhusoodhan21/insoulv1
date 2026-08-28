import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// InSoul insole BLE service.
///
/// This connection flow (permissions -> scan with webOptionalServices ->
/// connect with License.nonprofit -> discoverServices -> setNotifyValue(true)
/// -> THEN subscribe to onValueReceived) is copied from the button_counter
/// reference project after it was confirmed working on a real device and on
/// Flutter Web. Swap kServiceUuid / kCharacteristicUuid for the actual
/// insole firmware's UUIDs once that sketch exists; the connection mechanics
/// below don't need to change.
class BleService extends ChangeNotifier {
  // TODO: replace with the real InSoul insole service/characteristic UUIDs
  // once the sensor firmware is written. Left as the button-counter's UUIDs
  // for now so this is a drop-in, testable connection path.
  static const String kServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String kCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String kTargetDeviceName = "GaitSymmetryAnalyzer";
  static const Set<String> kTargetDeviceNames = {
    'GaitSymmetryAnalyzer',
    'SmartGait_L',
    'SmartGait_R',
    'InSoul',
    'ButtonCounter',
  };

  final List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;

  BluetoothDevice? device;
  BluetoothConnectionState connectionState =
      BluetoothConnectionState.disconnected;
  String status = 'Not connected';

  // Live values received from the ESP32 gait firmware.
  int stepCount = 0;
  int leftStepCount = 0;
  int rightStepCount = 0;
  double? symmetryScore;
  int? leftToRightMs;
  int? rightToLeftMs;
  double? accelerationX;
  double? accelerationY;
  double? accelerationZ;
  double? gyroscopeX;
  double? gyroscopeY;
  double? gyroscopeZ;
  DateTime? lastPacketAt;
  int packetCount = 0;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanStateSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<void>? _servicesResetSub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 20;
  bool _autoReconnect = true;
  bool _connecting = false;

  // True once we've successfully read/subscribed at least once this app
  // session. Lets the UI keep showing the last real value (instead of a
  // placeholder) while a brief reconnect is in progress.
  bool hasEverConnected = false;

  bool get connected => connectionState == BluetoothConnectionState.connected;

  BleService({bool initialize = true}) {
    if (!initialize) return;
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      adapterState = s;
      notifyListeners();
    });
    _scanStateSub = FlutterBluePlus.isScanning.listen((scanning) {
      isScanning = scanning;
      notifyListeners();
    });
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final bluetoothDenied =
        [
          permissions[Permission.bluetoothScan],
          permissions[Permission.bluetoothConnect],
        ].any(
          (status) =>
              status == null ||
              status.isDenied ||
              status.isPermanentlyDenied ||
              status.isRestricted,
        );
    if (bluetoothDenied) {
      throw Exception('Bluetooth permissions were denied');
    }
  }

  Future<void> startScan() async {
    if (isScanning) return;
    try {
      await _requestPermissions();
    } catch (e) {
      status = 'Scan blocked: $e';
      notifyListeners();
      return;
    }
    final adapterUnavailable =
        adapterState == BluetoothAdapterState.off ||
        adapterState == BluetoothAdapterState.unauthorized ||
        adapterState == BluetoothAdapterState.unavailable;
    if (!kIsWeb && adapterUnavailable) {
      status = 'Bluetooth is off or unavailable';
      notifyListeners();
      return;
    }
    scanResults.clear();
    isScanning = true;
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final idx = scanResults.indexWhere(
          (e) => e.device.remoteId == r.device.remoteId,
        );
        if (idx >= 0) {
          scanResults[idx] = r;
        } else {
          scanResults.add(r);
        }
      }
      scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
      notifyListeners();
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        // Required for Flutter Web (Web Bluetooth's requestDevice() only
        // grants access to services listed here at scan time) — harmless
        // on Android/iOS.
        webOptionalServices: [Guid(kServiceUuid)],
      );
    } catch (_) {
      isScanning = false;
      status = 'Scan failed. Check Bluetooth permissions and try again.';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    isScanning = false;
    notifyListeners();
  }

  Future<bool> connectTo(BluetoothDevice d) async {
    await stopScan();
    device = d;
    _autoReconnect = true;
    _reconnectAttempts = 0;
    status = 'Connecting...';
    notifyListeners();

    _connSub?.cancel();
    _connSub = d.connectionState.listen((s) {
      connectionState = s;
      if (s == BluetoothConnectionState.disconnected) {
        // The old GATT link is dead (e.g. the ESP32 was just re-flashed
        // and reset). Drop the stale subscriptions and, if we're supposed
        // to stay connected, start retrying instead of sitting frozen.
        _notifySub?.cancel();
        _servicesResetSub?.cancel();
        if (_autoReconnect) {
          status = 'Reconnecting...';
          _scheduleReconnect(d);
        }
      }
      notifyListeners();
    });

    return _connect(d);
  }

  /// Retries the connection with a short backoff. This is the case that
  /// matters for "I pressed build on the ESP32" — the board reboots, the
  /// BLE link drops hard (no clean disconnect packet), and the ESP32 needs
  /// a few seconds to finish booting and start advertising again. A single
  /// fixed-timeout attempt often loses that race; retrying doesn't.
  void _scheduleReconnect(BluetoothDevice d) {
    _reconnectTimer?.cancel();
    if (!_autoReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      status = 'Lost connection — tap to reconnect';
      _autoReconnect = false;
      notifyListeners();
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts < 6 ? 2 : 5);
    status = 'Reconnecting (attempt $_reconnectAttempts)...';
    notifyListeners();
    _reconnectTimer = Timer(delay, () {
      if (_autoReconnect) _connect(d);
    });
  }

  Future<bool> _connect(BluetoothDevice d) async {
    if (_connecting) return false;
    _connecting = true;
    try {
      // license is a required parameter as of flutter_blue_plus 2.0 —
      // matches the verified-working reference project's connect() call.
      await d.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );
      status = 'Connected — discovering services...';
      notifyListeners();
      final ready = await _discoverAndSubscribe(d);
      if (!ready) {
        // Wrong/missing service or characteristic — a real mismatch, not
        // a "still booting" issue, so don't keep retrying forever.
        _autoReconnect = false;
        await d.disconnect();
      } else {
        _reconnectAttempts = 0;
        hasEverConnected = true;
      }
      return ready;
    } catch (e) {
      // Most likely cause during development: the board hasn't finished
      // rebooting/re-advertising yet. Retry instead of giving up.
      status = 'Connect failed, retrying...';
      connectionState = BluetoothConnectionState.disconnected;
      notifyListeners();
      if (_autoReconnect) _scheduleReconnect(d);
      return false;
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _discoverAndSubscribe(BluetoothDevice d) async {
    try {
      try {
        await d.requestMtu(247);
      } catch (_) {
        // not fatal, not all platforms support this
      }

      final services = await d.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.str128.toLowerCase() == kServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Service UUID not found on device'),
      );
      final char = service.characteristics.firstWhere(
        (c) => c.uuid.str128.toLowerCase() == kCharacteristicUuid.toLowerCase(),
        orElse: () => throw Exception('Characteristic UUID not found'),
      );
      if (!char.properties.read && !char.properties.notify) {
        throw Exception('Step characteristic cannot be read or notified');
      }

      // Read the current value immediately so the UI isn't stuck at 0
      // until the next button press / step.
      if (char.properties.read) {
        final value = await char.read();
        _updateStepCountFromBytes(value);
      }

      // Enable notifications BEFORE subscribing to onValueReceived — this
      // ordering is what fixed the "connects but never receives data" bug.
      if (char.properties.notify) {
        await char.setNotifyValue(true);
        _notifySub?.cancel();
        _notifySub = char.onValueReceived.listen((value) {
          _updateStepCountFromBytes(value);
        });
      }

      // Android caches each device's GATT table. If the ESP32 reboots
      // while Android still thinks it's connected (common right after a
      // re-flash), Android can serve the *old* table/value. It signals a
      // change via the GAP "Service Changed" indication — when that fires,
      // we must re-discover services and re-subscribe or notifications
      // silently stop even though the app still shows "connected".
      _servicesResetSub?.cancel();
      _servicesResetSub = d.onServicesReset.listen((_) async {
        await _discoverAndSubscribe(d);
      });

      status = 'Connected — listening';
      notifyListeners();
      return true;
    } catch (e) {
      status = 'Setup failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Parses gait JSON payloads and the legacy integer format.
  void _updateStepCountFromBytes(List<int> value) {
    final str = utf8.decode(value, allowMalformed: true).trim();
    int? parsed = int.tryParse(str);
    if (parsed == null) {
      try {
        final packet = jsonDecode(str);
        if (packet is Map) {
          final type = packet['type'];
          if (type == 'count') {
            parsed = _intValue(packet['total']);
            leftStepCount = _intValue(packet['l']) ?? leftStepCount;
            rightStepCount = _intValue(packet['r']) ?? rightStepCount;
          } else if (type == 'symmetry') {
            symmetryScore = _numberValue(packet['score']);
            leftToRightMs = _intValue(packet['ltrMs']);
            rightToLeftMs = _intValue(packet['rtlMs']);
          }

          final steps = packet['steps'];
          parsed ??= steps is num ? steps.toInt() : int.tryParse('$steps');

          final imu = packet['imu'];
          if (imu is Map) {
            accelerationX = _numberValue(imu['ax']);
            accelerationY = _numberValue(imu['ay']);
            accelerationZ = _numberValue(imu['az']);
            gyroscopeX = _numberValue(imu['gx']);
            gyroscopeY = _numberValue(imu['gy']);
            gyroscopeZ = _numberValue(imu['gz']);
          }
        }
      } on FormatException {
        // Ignore an incomplete or malformed BLE packet.
      }
    }
    packetCount++;
    lastPacketAt = DateTime.now();
    if (parsed != null) {
      stepCount = parsed;
    }
    notifyListeners();
  }

  double? _numberValue(Object? value) {
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  int? _intValue(Object? value) {
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _servicesResetSub?.cancel();
    await device?.disconnect();
    status = 'Not connected';
    stepCount = 0;
    leftStepCount = 0;
    rightStepCount = 0;
    symmetryScore = null;
    leftToRightMs = null;
    rightToLeftMs = null;
    accelerationX = null;
    accelerationY = null;
    accelerationZ = null;
    gyroscopeX = null;
    gyroscopeY = null;
    gyroscopeZ = null;
    lastPacketAt = null;
    packetCount = 0;
    hasEverConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    _adapterSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _servicesResetSub?.cancel();
    super.dispose();
  }
}

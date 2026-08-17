import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

enum BtConnectionState { disconnected, connecting, connected, error }

class BluetoothService {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  String _receiveBuffer = '';

  final StreamController<BtConnectionState> _stateController =
      StreamController<BtConnectionState>.broadcast();
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  final StreamController<String> _sentController =
      StreamController<String>.broadcast();

  BtConnectionState _currentState = BtConnectionState.disconnected;

  Stream<BtConnectionState> get stateStream => _stateController.stream;
  Stream<String> get dataStream => _dataController.stream;
  Stream<String> get sentStream => _sentController.stream;
  BtConnectionState get currentState => _currentState;

  BluetoothService() {
    _stateController.add(_currentState);
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Stream<BluetoothDevice> discoverDevices() {
    return _bluetooth.startDiscovery().map((r) => r.device);
  }

  Future<bool> connect(BluetoothDevice device) async {
    _setState(BtConnectionState.connecting);
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _receiveBuffer = '';
      _setState(BtConnectionState.connected);

      _connection!.input!.listen(
        (data) {
          _receiveBuffer += utf8.decode(data, allowMalformed: true);

          int newlineIndex;
          while ((newlineIndex = _receiveBuffer.indexOf('\n')) >= 0) {
            var line = _receiveBuffer.substring(0, newlineIndex);
            _receiveBuffer = _receiveBuffer.substring(newlineIndex + 1);
            if (line.endsWith('\r')) {
              line = line.substring(0, line.length - 1);
            }
            if (line.isNotEmpty) {
              _dataController.add(line);
            }
          }
        },
        onError: (error) {
          _dataController.add('BLUETOOTH ERROR: $error');
          _setState(BtConnectionState.error);
        },
        onDone: () => _setState(BtConnectionState.disconnected),
      );

      return true;
    } catch (_) {
      _setState(BtConnectionState.error);
      return false;
    }
  }

  void disconnect() {
    _connection?.close();
    _connection = null;
    _receiveBuffer = '';
    _setState(BtConnectionState.disconnected);
  }

  void send(String command) {
    _sentController.add(command);
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(utf8.encode('$command\n'));
    }
  }

  void _setState(BtConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _dataController.close();
    _sentController.close();
  }
}

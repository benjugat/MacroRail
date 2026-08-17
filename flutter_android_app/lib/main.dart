import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_service.dart';
import 'screens/manual_screen.dart';
import 'screens/automatic_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MacroRailApp());
}

class MacroRailApp extends StatelessWidget {
  const MacroRailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacroRail App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          secondary: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 70,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final BluetoothService _bt;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _bt = BluetoothService();
    _screens = [
      ConexionScreen(bt: _bt),
      ManualScreen(bt: _bt),
      AutomaticScreen(bt: _bt),
    ];
  }

  @override
  void dispose() {
    _bt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MacroRail App'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StreamBuilder<BtConnectionState>(
              stream: _bt.stateStream,
              builder: (_, snap) {
                final state = snap.data ?? BtConnectionState.disconnected;
                final connected = state == BtConnectionState.connected;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: connected ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      connected ? 'Conectado' : 'Desconectado',
                      style: TextStyle(
                        fontSize: 12,
                        color: connected ? Colors.green : Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'Conexión',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Manual',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'Automático',
          ),
        ],
      ),
    );
  }
}

class ConexionScreen extends StatefulWidget {
  final BluetoothService bt;
  const ConexionScreen({super.key, required this.bt});

  @override
  State<ConexionScreen> createState() => _ConexionScreenState();
}

class _ConexionScreenState extends State<ConexionScreen> {
  BluetoothService get _bt => widget.bt;
  final List<String> _log = [];
  final ScrollController _scrollController = ScrollController();
  final _delayController = TextEditingController(text: '2.0');
  final _expoController = TextEditingController(text: '4.0');

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selected;
  BtConnectionState _state = BtConnectionState.disconnected;

  StreamSubscription? _stateSub;
  StreamSubscription? _dataSub;
  StreamSubscription? _sentSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _bt.stateStream.listen((s) {
      setState(() => _state = s);
      _logMsg('SYSTEM  $s');
    });
    _dataSub = _bt.dataStream.listen((data) {
      for (final line in data.split('\n')) {
        if (line.isNotEmpty) _logMsg('RX < $line');
      }
    });
    _sentSub = _bt.sentStream.listen((cmd) {
      _logMsg('TX > $cmd');
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _dataSub?.cancel();
    _sentSub?.cancel();
    _delayController.dispose();
    _expoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _logMsg(String m) {
    setState(() => _log.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _scan() async {
    if (await _requestPermissions()) {
      setState(() => _devices = []);
      _logMsg('SYSTEM  Scanning...');
      try {
        final bonded = await _bt.getBondedDevices();
        _logMsg('SYSTEM  ${bonded.length} bonded device(s) found');
        setState(() => _devices = bonded);

        await for (final device in _bt.discoverDevices()) {
          setState(() {
            if (!_devices.any((d) => d.address == device.address)) {
              _devices.add(device);
              _logMsg('SYSTEM  Discovered ${device.name ?? device.address}');
            }
          });
        }
        _logMsg('SYSTEM  Scan finished');
      } catch (e) {
        _logMsg('ERROR  $e');
      }
    }
  }

  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
    for (final p in permissions) {
      if (!await p.isGranted) {
        final statuses = await permissions.request();
        return statuses.values.every((s) => s.isGranted);
      }
    }
    return true;
  }

  Future<void> _connect() async {
    if (_selected == null) return;
    final ok = await _bt.connect(_selected!);
    if (!ok) _logMsg('ERROR  Connection failed');
  }

  Color _statusColor() => switch (_state) {
        BtConnectionState.disconnected => Colors.grey,
        BtConnectionState.connecting => Colors.orange,
        BtConnectionState.connected => Colors.green,
        BtConnectionState.error => Colors.red,
      };

  IconData _statusIcon() => switch (_state) {
        BtConnectionState.disconnected => Icons.bluetooth_disabled,
        BtConnectionState.connecting => Icons.bluetooth_searching,
        BtConnectionState.connected => Icons.bluetooth_connected,
        BtConnectionState.error => Icons.error_outline,
      };

  String _statusText() => switch (_state) {
        BtConnectionState.disconnected => 'Disconnected',
        BtConnectionState.connecting => 'Connecting\u2026',
        BtConnectionState.connected => 'Connected',
        BtConnectionState.error => 'Error',
      };

  void _sendDelay() {
    final v = double.tryParse(_delayController.text.trim());
    if (v != null) _bt.send('CONFIG DELAY ${(v * 1000).toInt()}');
  }

  void _sendExpo() {
    final v = double.tryParse(_expoController.text.trim());
    if (v != null) {
      _bt.send('CONFIG EXPOSURE ${(v * 1000).toInt()}');
    }
  }

  Widget _configCard() {
    final connected = _state == BtConnectionState.connected;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuración',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.primary,
                    )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _delayController,
                    decoration: const InputDecoration(
                      labelText: 'Tiempo de delay (s)',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: connected ? _sendDelay : null,
                  child: const Text('Enviar Delay'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _expoController,
                    decoration: const InputDecoration(
                      labelText: 'Tiempo de exposición (s)',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: connected ? _sendExpo : null,
                  child: const Text('Enviar Exposure'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor();
    return ListView(
      children: [
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: Icon(_statusIcon(), color: statusColor, size: 32),
            title: Text(_statusText(),
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
            subtitle: _selected != null
                ? Text(_selected!.name ?? _selected!.address,
                    style: const TextStyle(fontSize: 13))
                : const Text('No device selected',
                    style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _scan,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Scan'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<BluetoothDevice>(
                    initialValue: _selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Select HC-05',
                      isDense: true,
                      border: OutlineInputBorder(),
                      filled: false,
                    ),
                    items: _devices
                        .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.name ?? d.address,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (d) => setState(() => _selected = d),
                  ),
                ),
                const SizedBox(width: 8),
                if (_state == BtConnectionState.connected)
                  FilledButton(
                    onPressed: _bt.disconnect,
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                    child: const Text('Disconnect'),
                  )
                else
                  FilledButton(
                    onPressed: _selected != null ? _connect : null,
                    child: const Text('Connect'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _configCard(),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 18),
                    const SizedBox(width: 6),
                    const Text('Log',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Badge(
                      label: Text('${_log.length}'),
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => setState(() => _log.clear()),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _log.length,
                    itemBuilder: (_, i) {
                      final e = _log[i];
                      Color? c;
                      if (e.startsWith('TX')) c = Colors.blue.shade700;
                      if (e.startsWith('RX')) c = Colors.green.shade700;
                      if (e.startsWith('ERROR')) c = Colors.red;
                      if (e.startsWith('SYSTEM')) c = Colors.grey.shade600;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(e,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: c,
                                      fontFamily: 'monospace')),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

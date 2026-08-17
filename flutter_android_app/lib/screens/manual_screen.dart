import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bluetooth_service.dart';

class ManualScreen extends StatefulWidget {
  final BluetoothService bt;
  const ManualScreen({super.key, required this.bt});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _moveController = TextEditingController();
  final _manualController = TextEditingController();
  BtConnectionState _state = BtConnectionState.disconnected;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.bt.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _moveController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  bool get _connected => _state == BtConnectionState.connected;

  void _send(String cmd) {
    if (cmd.isNotEmpty) widget.bt.send(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comandos rápidos',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        )),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _btn(Icons.home, 'HOME'),
                    _btn(Icons.favorite_border, 'PING'),
                    _btn(Icons.camera_alt_outlined, 'PHOTO'),
                    _btn(Icons.stop_circle_outlined, 'STOP'),
                    _btn(Icons.info_outline, 'STATUS'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mover',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _moveController,
                        decoration: const InputDecoration(
                          labelText: 'Distancia (mm)',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*$'))
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _connected
                          ? () {
                              final d =
                                  double.tryParse(_moveController.text.trim());
                              if (d != null) {
                                _send('MOVE ${(d * 1000).toInt()}');
                              }
                            }
                          : null,
                      child: const Text('MOVE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comando manual',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un comando',
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          if (v.isNotEmpty) {
                            _send(v);
                            _manualController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _connected
                          ? () {
                              final t = _manualController.text.trim();
                              if (t.isNotEmpty) {
                                _send(t);
                                _manualController.clear();
                              }
                            }
                          : null,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Enviar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn(IconData icon, String label) {
    return FilledButton.tonal(
      onPressed: _connected ? () => _send(label) : null,
      child: Text(label),
    );
  }
}

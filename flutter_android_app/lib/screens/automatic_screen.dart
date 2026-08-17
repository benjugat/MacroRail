import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bluetooth_service.dart';

class AutomaticScreen extends StatefulWidget {
  final BluetoothService bt;
  const AutomaticScreen({super.key, required this.bt});

  @override
  State<AutomaticScreen> createState() => _AutomaticScreenState();
}

class _AutomaticScreenState extends State<AutomaticScreen> {
  final _distController = TextEditingController();
  final _qtyController = TextEditingController();
  double _totalDistance = 0;

  bool _autoRunning = false;
  int _autoCurrent = 0;
  int _autoTotal = 0;
  StreamSubscription? _dataSub;

  @override
  void initState() {
    super.initState();
    _distController.addListener(_recalc);
    _qtyController.addListener(_recalc);
    _dataSub = widget.bt.dataStream.listen((data) {
      for (final line in data.split('\n')) {
        final t = line.trim();
        if (t.startsWith('AUTO START')) {
          final parts = t.split(' ');
          final total = parts.length >= 3 ? int.tryParse(parts[2]) ?? 0 : 0;
          setState(() {
            _autoRunning = true;
            _autoCurrent = 0;
            _autoTotal = total;
          });
        } else if (t == 'STOP' ||
            t == 'LIMIT STOP' ||
            t == 'AUTO DONE' ||
            t.startsWith('AUTO STOPPED')) {
          setState(() => _autoRunning = false);
        } else if (t == 'PHOTO' && _autoRunning) {
          setState(() => _autoCurrent++);
        }
      }
    });
  }

  @override
  void dispose() {
    _distController.removeListener(_recalc);
    _qtyController.removeListener(_recalc);
    _distController.dispose();
    _qtyController.dispose();
    _dataSub?.cancel();
    super.dispose();
  }

  void _recalc() {
    final dist = double.tryParse(_distController.text) ?? 0;
    final qty = double.tryParse(_qtyController.text) ?? 0;
    setState(() {
      _totalDistance = qty > 0 ? qty * dist : 0;
    });
  }

  void _enviar() {
    final dist = double.tryParse(_distController.text.trim());
    final qty = int.tryParse(_qtyController.text.trim());
    if (dist == null || qty == null) return;
    final cmd = 'AUTO ${(dist * 1000).toInt()} $qty';
    widget.bt.send(cmd);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviado: $cmd'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _distController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                decoration: const InputDecoration(
                  labelText: 'Distancia entre fotos (mm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Cantidad de fotos',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.straighten),
                    const SizedBox(width: 12),
                    Text(
                      'Distancia total: ${_totalDistance.toStringAsFixed(1)} mm',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_autoRunning)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: _autoTotal > 0
                                  ? _autoCurrent / _autoTotal
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Progreso: $_autoCurrent / $_autoTotal fotos',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => widget.bt.send('STOP'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor:
                            Theme.of(context).colorScheme.onError,
                      ),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('STOP'),
                    ),
                  ],
                ),
              if (!_autoRunning)
                FilledButton.icon(
                  onPressed: _enviar,
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

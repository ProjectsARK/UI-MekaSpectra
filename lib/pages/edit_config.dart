import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class EditConfigPage extends StatefulWidget {
  const EditConfigPage({super.key});

  @override
  State<EditConfigPage> createState() => _EditConfigPageState();
}

class _EditConfigPageState extends State<EditConfigPage> {
  final _formKey = GlobalKey<FormState>();
  bool isConnected = false;
  bool isSaving = false;
  bool _isFetching = false; // cegah fetch berulang/bertumpuk

  // 18 kanal
  List<double> whiteReference = List.filled(18, 0);
  List<double> darkReference  = List.filled(18, 0);

  final averagingController       = TextEditingController();
  final integrationTimeController = TextEditingController();

  static const _baseUrl = "http://192.168.4.1";

  static const List<double> _wavelengths = [
    410, 435, 460, 485, 510, 535, 560, 585, 610,
    645, 680, 705, 730, 760, 810, 860, 900, 940,
  ];

  @override
  void initState() {
    super.initState();
    _fetchConfigs(); // fetch sekali saat dibuka
  }

  @override
  void dispose() {
    averagingController.dispose();
    integrationTimeController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfigs() async {
    if (_isFetching || !mounted) return;
    _isFetching = true;
    try {
      final res = await http
          .get(Uri.parse("$_baseUrl/configs"))
          .timeout(const Duration(seconds: 3));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (!mounted) return;
        setState(() {
          isConnected = true;
          averagingController.text       = (data['avg'] ?? '').toString();
          integrationTimeController.text = (data['ic']  ?? '').toString();

          whiteReference = (data['wr'] as List? ?? const [])
              .map((e) => (e as num).toDouble()).toList()
              .padRight(18, 0.0).take(18).toList();

          darkReference = (data['dr'] as List? ?? const [])
              .map((e) => (e as num).toDouble()).toList()
              .padRight(18, 0.0).take(18).toList();
        });
      } else {
        _setDisconnected();
      }
    } catch (_) {
      _setDisconnected();
    } finally {
      _isFetching = false;
    }
  }

  void _setDisconnected() {
    if (!mounted) return;
    setState(() {
      isConnected = false;
      whiteReference = List.filled(18, 0);
      darkReference  = List.filled(18, 0);
    });
  }

  Future<void> _saveConfigs() async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted) setState(() => isSaving = true);

    try {
      final res = await http
          .post(Uri.parse("$_baseUrl/configs"), body: {
            "avg": averagingController.text,
            "ic" : integrationTimeController.text,
          })
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Konfigurasi berhasil disimpan")),
        );
        await _fetchConfigs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan: ${res.statusCode}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saat menyimpan: $e")),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // --- Chart helpers ---

  /// Anchor sumbu Y di 0 (dasar grafik) + headroom 10% di atas.
  (double minY, double maxY) _computeYBounds() {
    final all = [...whiteReference, ...darkReference];
    double maxY = all.isEmpty ? 1 : all.reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) maxY = 1;
    const headroom = 0.10; // 10%
    return (0, maxY * (1 + headroom));
  }

  /// Label bawah: pakai nm dari [_wavelengths], tampil tiap 2 titik agar rapi.
  SideTitles _bottomTitles() {
    return SideTitles(
      showTitles: true,
      reservedSize: 26,
      getTitlesWidget: (value, meta) {
        // Karena sumbu X pakai nm langsung, cari label yang dekat (±3 nm)
        String? label;
        for (int i = 0; i < _wavelengths.length; i++) {
          final w = _wavelengths[i];
          if ((value - w).abs() <= 3) {
            if (i % 2 == 0) label = w.toInt().toString();
            break;
          }
        }
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(label, style: const TextStyle(fontSize: 10)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (minY, maxY) = _computeYBounds();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuration"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _isFetching ? null : _fetchConfigs, // disable saat fetch
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // Pull-to-refresh
      body: RefreshIndicator(
        onRefresh: _fetchConfigs,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Status koneksi
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(isConnected ? "Terkoneksi" : "Tidak terkoneksi"),
              ],
            ),

            const SizedBox(height: 16),

            // === Calibration references (Chart) ===
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        "Calibration references",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 240,
                      child: LineChart(
                        LineChartData(
                          minX: _wavelengths.first,
                          maxX: _wavelengths.last,
                          minY: minY,
                          maxY: maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            drawHorizontalLine: true,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: cs.outlineVariant, strokeWidth: 1, dashArray: [6, 6],
                            ),
                            getDrawingVerticalLine: (v) => FlLine(
                              color: cs.outlineVariant, strokeWidth: 1, dashArray: [6, 6],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(sideTitles: _bottomTitles()),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: cs.outline),
                          ),
                          lineBarsData: [
                            // White Reference — tipis, mulus, tanpa titik (gradasi)
                            LineChartBarData(
                              spots: List.generate(
                                whiteReference.length,
                                (i) => FlSpot(_wavelengths[i], whiteReference[i]),
                              ),
                              isCurved: true,
                              barWidth: 2,               // seragam & tipis
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1E3A8A), // biru
                                  Colors.green,
                                  Color(0xFFFF1C00), // merah terang
                                  Color(0xFFC00000),
                                  Color(0xFF780800),
                                  Color(0xFF4D0500),
                                ],
                              ),
                              dotData: const FlDotData(show: false),
                            ),
                            // Dark Reference — tipis, mulus, tanpa titik (hitam)
                            LineChartBarData(
                              spots: List.generate(
                                darkReference.length,
                                (i) => FlSpot(_wavelengths[i], darkReference[i]),
                              ),
                              isCurved: true,
                              color: Colors.black,
                              barWidth: 2,               // seragam
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // === Form pengaturan ===
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Acquisition Settings",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: averagingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: "Averaging value",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null) return "Harus angka";
                          if (n < 1) return "Minimal 1";
                          if (n > 256) return "Maksimal 256";
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: integrationTimeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: "Integration Cycle (ms)",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null) return "Harus angka";
                          if (n < 1) return "Minimal 1 ms";
                          if (n > 10000) return "Maksimal 10000 ms";
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveConfigs,
                          child: isSaving
                              ? const CircularProgressIndicator()
                              : const Text("Save Configuration"),
                        ),
                      ),
                    ],
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

// util: padRight untuk List
extension _PadRight<T> on List<T> {
  List<T> padRight(int length, T fill) {
    if (this.length >= length) return this;
    return [...this, ...List.filled(length - this.length, fill)];
  }
}

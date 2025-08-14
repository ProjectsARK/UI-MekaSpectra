import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class EditConfigPage extends StatefulWidget {
  const EditConfigPage({super.key});

  @override
  State<EditConfigPage> createState() => _EditConfigPageState();
}

class _EditConfigPageState extends State<EditConfigPage> {
  final _formKey = GlobalKey<FormState>();
  bool isConnected = false;
  bool isSaving = false;

  Timer? _timer;

  // Data dari device
  List<double> whiteReference = List.filled(19, 0);
  List<double> darkReference  = List.filled(19, 0);

  // Controller form
  final averagingController        = TextEditingController();
  final integrationTimeController  = TextEditingController();

  static const _baseUrl = "http://192.168.4.1";

  @override
void initState() {
  super.initState();
  _fetchConfigs();
  // polling ringan agar status & nilai update berkala
  _timer = Timer.periodic(const Duration(seconds: 5), (t) async {
    if (!mounted) {
      t.cancel();                 // pastikan berhenti saat halaman ditutup
      return;
    }
    await _fetchConfigs();
  });
}

@override
void dispose() {
  _timer?.cancel();
  averagingController.dispose();
  integrationTimeController.dispose();
  super.dispose();
}

Future<void> _fetchConfigs() async {
  try {
    final res = await http
        .get(Uri.parse("$_baseUrl/configs"))
        .timeout(const Duration(seconds: 3));

    if (!mounted) return;         // guard setelah await

    if (res.statusCode == 200) {
      final data = json.decode(res.body);

      if (!mounted) return;       // guard sebelum setState & controller
      setState(() {
        isConnected = true;

        averagingController.text = (data['avg'] ?? '').toString();
        integrationTimeController.text = (data['ic'] ?? '').toString();

        whiteReference = (data['wr'] as List? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList()
            .padRight(19, 0.0)
            .take(19)
            .toList();

        darkReference = (data['dr'] as List? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList()
            .padRight(19, 0.0)
            .take(19)
            .toList();
      });
    } else {
      _setDisconnected();
    }
  } catch (_) {
    _setDisconnected();
  }
}

void _setDisconnected() {
  if (!mounted) return;           // jangan setState jika sudah dispose
  setState(() {
    isConnected = false;
    whiteReference = List.filled(19, 0);
    darkReference  = List.filled(19, 0);
    // biarkan nilai form apa adanya agar user bisa menulis lalu save saat tersambung lagi
  });
}

Future<void> _saveConfigs() async {
  if (!_formKey.currentState!.validate()) return;

  if (mounted) setState(() => isSaving = true);

  try {
    final res = await http
        .post(
          Uri.parse("$_baseUrl/configs"),
          body: {
            "avg": averagingController.text,
            "ic" : integrationTimeController.text,
          },
        )
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            onPressed: _fetchConfigs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
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

            // Ringkasan reference (tabel 3 kolom yang ringkas untuk mobile)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Reference Preview",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 320,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Ch')),
                            DataColumn(label: Text('White')),
                            DataColumn(label: Text('Dark')),
                          ],
                          rows: List.generate(19, (i) {
                            final w = (i < whiteReference.length)
                                ? whiteReference[i]
                                : 0.0;
                            final d = (i < darkReference.length)
                                ? darkReference[i]
                                : 0.0;
                            return DataRow(cells: [
                              DataCell(Text('${i + 1}')),
                              DataCell(Text(w.toStringAsFixed(3))),
                              DataCell(Text(d.toStringAsFixed(3))),
                            ]);
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Form pengaturan
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

                      // Averaging
                      TextFormField(
                        controller: averagingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: "Averaging",
                          border: OutlineInputBorder(),
                        ),
                        // validator tetap seperti sebelumnya...
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: integrationTimeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: "Integration Time (ms)",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tombol Save
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveConfigs,
                          child: isSaving
                              ? const CircularProgressIndicator()
                              : const Text("Save"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Info kecil
            Text(
              "Catatan: nilai pada tabel di atas adalah pratinjau white/dark reference dari perangkat.",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// --- util extension kecil untuk mempermudah padRight list ---
extension _PadRight<T> on List<T> {
  List<T> padRight(int length, T fill) {
    if (this.length >= length) return this;
    return [...this, ...List.filled(length - this.length, fill)];
  }
}

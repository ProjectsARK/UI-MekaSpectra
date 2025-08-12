import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditConfigPage extends StatefulWidget {
  const EditConfigPage({super.key});

  @override
  State<EditConfigPage> createState() => _EditConfigPageState();
}

class _EditConfigPageState extends State<EditConfigPage> {
  bool isConnected = false;
  Timer? _timer;

  // Nilai white & dark reference (read-only)
  List<double> whiteReference = List.filled(19, 0);
  List<double> darkReference = List.filled(19, 0);

  // Controller untuk 2 input setting di bawah
  final TextEditingController averagingController = TextEditingController();
  final TextEditingController integrationTimeController = TextEditingController();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchConfig();
    });
  }

  Future<void> _fetchConfig() async {
    try {
      final response = await http.get(Uri.parse("http://192.168.4.1/config")).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          isConnected = true;

          // Ambil whiteReference dan darkReference dari response
          whiteReference = List<double>.from(data['white_reference'] ?? List.filled(19, 0));
          darkReference = List<double>.from(data['dark_reference'] ?? List.filled(19, 0));

          averagingController.text = data['averaging']?.toString() ?? '';
          integrationTimeController.text = data['integration_time']?.toString() ?? '';
        });
      } else {
        _setDisconnected();
      }
    } catch (e) {
      _setDisconnected();
    }
  }

  void _setDisconnected() {
    setState(() {
      isConnected = false;
      whiteReference = List.filled(19, 0);
      darkReference = List.filled(19, 0);
      averagingController.text = '';
      integrationTimeController.text = '';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    averagingController.dispose();
    integrationTimeController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() {
      isSaving = true;
    });

    final body = {
      "averaging": int.tryParse(averagingController.text) ?? 0,
      "integration_time": int.tryParse(integrationTimeController.text) ?? 0,
    };

    try {
      final response = await http.post(
        Uri.parse("http://192.168.4.1/config"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Konfigurasi berhasil disimpan")),
        );
        _fetchConfig(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan konfigurasi: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saat menyimpan konfigurasi: $e")),
      );
    }

    setState(() {
      isSaving = false;
    });
  }

  Widget _buildReferenceColumn(String label, List<double> values) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: values
                  .map((v) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(v.toStringAsFixed(3)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWavelengthTable(List<double> whiteRef, List<double> darkRef) {
    // Tabel 2 baris x 19 kolom, baris 1 = whiteRef, baris 2 = darkRef
    final columns = List.generate(19, (index) => (index + 1).toString());

    return Expanded(
      flex: 3,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Wavelength')),
            ...columns.map((c) => DataColumn(label: Text(c))),
          ],
          rows: [
            DataRow(cells: [
              const DataCell(Text('White Ref')),
              ...whiteRef.map((v) => DataCell(Text(v.toStringAsFixed(3)))).toList(),
            ]),
            DataRow(cells: [
              const DataCell(Text('Dark Ref')),
              ...darkRef.map((v) => DataCell(Text(v.toStringAsFixed(3)))).toList(),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuration"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // kembali ke home
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            const SizedBox(height: 20),

            // Baris atas: White Reference dan Dark Reference + Tabel 2x19
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReferenceColumn("White Reference", whiteReference),
                const SizedBox(width: 16),
                _buildReferenceColumn("Dark Reference", darkReference),
                const SizedBox(width: 16),
                _buildWavelengthTable(whiteReference, darkReference),
              ],
            ),
            const SizedBox(height: 24),

            // Input Averaging dan Integration Time
            TextFormField(
              controller: averagingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Averaging"),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: integrationTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Integration Time"),
            ),

            const SizedBox(height: 30),

            // Tombol Save
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveConfig,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

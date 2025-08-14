import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class GetDataPage extends StatefulWidget {
  const GetDataPage({super.key});

  @override
  State<GetDataPage> createState() => _GetDataPageState();
}

class _GetDataPageState extends State<GetDataPage> {
  List<List<dynamic>> predictionResults = [];
  List<List<dynamic>> acquisitionResults = [];
  bool connected = false;

  Timer? _timer;
  bool _isFetching = false; // cegah fetch bertumpuk

  static const _baseUrl = "http://192.168.4.1";

  @override
  void initState() {
    super.initState();
    // panggilan awal
    fetchData();
    // polling berkala
    _timer = Timer.periodic(const Duration(seconds: 5), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      await fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    if (_isFetching || !mounted) return;
    _isFetching = true;

    try {
      final resResults = await http
          .get(Uri.parse("$_baseUrl/data/results"))
          .timeout(const Duration(seconds: 3));
      if (!mounted) {
        _isFetching = false;
        return;
      }

      final resCaptures = await http
          .get(Uri.parse("$_baseUrl/data/captures"))
          .timeout(const Duration(seconds: 3));
      if (!mounted) {
        _isFetching = false;
        return;
      }

      if (resResults.statusCode == 200 && resCaptures.statusCode == 200) {
        // Parse CSV aman (dibungkus try agar tidak crash bila CSV kosong/invalid)
        List<List<dynamic>> parsedResults = const [];
        List<List<dynamic>> parsedCaptures = const [];
        try {
          parsedResults =
              const CsvToListConverter(eol: '\n').convert(resResults.body);
        } catch (_) {}
        try {
          parsedCaptures =
              const CsvToListConverter(eol: '\n').convert(resCaptures.body);
        } catch (_) {}

        if (!mounted) {
          _isFetching = false;
          return;
        }
        setState(() {
          connected = true;
          predictionResults = _maybeDropHeader(parsedResults);
          acquisitionResults = _maybeDropHeader(parsedCaptures);
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

  List<List<dynamic>> _maybeDropHeader(List<List<dynamic>> rows) {
    if (rows.isEmpty) return rows;
    final f = rows.first.map((e) => e.toString().toLowerCase()).toList();
    final looksHeader = f.any((s) =>
        s.contains('date') ||
        s.contains('result') ||
        s.contains('wavelength') ||
        s == 'lt' ||
        s == 'at');
    return looksHeader ? rows.skip(1).toList() : rows;
  }

  void _setDisconnected() {
    if (!mounted) return;
    setState(() {
      connected = false;
      predictionResults = [];
      acquisitionResults = [];
    });
  }

  Future<void> exportCSV(List<List<dynamic>> data, String fileName) async {
    if (data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data kosong, tidak bisa diunduh")),
        );
      }
      return;
    }

    final csvData = const ListToCsvConverter().convert(data);
    final directory = await getExternalStorageDirectory();
    final path = "${directory!.path}/$fileName.csv";
    final file = File(path);
    await file.writeAsString(csvData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File saved: $path")),
      );
    }
  }

  Future<void> _showInfo() async {
    try {
      final res = await http
          .get(Uri.parse("$_baseUrl/info"))
          .timeout(const Duration(seconds: 3));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final storage = (data['storage'] as num?)?.toDouble() ?? 0.0;

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Sensor Info'),
            content: Text('Storage: ${storage.toStringAsFixed(2)} MB'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      } else {
        _snack("Gagal membaca info (${res.statusCode})");
      }
    } catch (e) {
      _snack("Error membaca info: $e");
    }
  }

  Future<void> _confirmDelete() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Semua Data?'),
        content: const Text('Tindakan ini akan menghapus semua data di sensor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) _deleteAllData();
  }

  Future<void> _deleteAllData() async {
    try {
      final res = await http
          .get(Uri.parse("$_baseUrl/data/delete"))
          .timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['formatted'] == true) {
          if (!mounted) return;
          setState(() {
            predictionResults = [];
            acquisitionResults = [];
          });
          _snack("Semua data berhasil dihapus");
        } else {
          _snack("Perangkat tidak menghapus data (formatted=false)");
        }
      } else {
        _snack("Gagal menghapus (${res.statusCode})");
      }
    } catch (e) {
      _snack("Error menghapus: $e");
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<dynamic> _fitRow(List<dynamic> row, int len) {
    final r = List<dynamic>.from(row);
    if (r.length > len) return r.sublist(0, len);
    if (r.length < len) r.addAll(List.filled(len - r.length, ''));
    return r;
  }

  @override
  Widget build(BuildContext context) {
    // Acquisition: Date, Lt, At, W1..W18
    final acqColumns = <String>[
      'Date', 'Lt', 'At', ...List.generate(18, (i) => 'W${i + 1}')
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Get Data"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status koneksi
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    connected ? Icons.check_circle : Icons.error,
                    color: connected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(connected ? "Terkoneksi" : "Tidak terkoneksi"),
                ],
              ),
            ),

            // Tombol di luar tabel Prediction
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showInfo,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Info'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All'),
                  ),
                ],
              ),
            ),

            // Prediction Results
            _buildTableSection(
              title: "Prediction Results",
              columns: const ['Date', 'Result', 'Lt', 'At'],
              data: predictionResults,
              onDownload: () => exportCSV(predictionResults, "prediction_results"),
            ),

            // Acquisition Results (W1..W18)
            _buildTableSection(
              title: "Acquisition Results",
              columns: acqColumns,
              data: acquisitionResults,
              onDownload: () => exportCSV(acquisitionResults, "acquisition_results"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSection({
    required String title,
    required List<String> columns,
    required List<List<dynamic>> data,
    required VoidCallback onDownload,
  }) {
    const int minRows = 6;
    final displayData =
        data.isEmpty ? List.generate(minRows, (_) => List.filled(columns.length, '')) : data;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
                      rows: displayData.map((row) {
                        final cells = _fitRow(row, columns.length);
                        return DataRow(
                          cells: cells.map((cell) => DataCell(Text(cell.toString()))).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download),
                  label: const Text('Download CSV'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

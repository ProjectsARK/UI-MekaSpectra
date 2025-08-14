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
  // Prediction
  List<String> predictionHeader = [];
  List<List<dynamic>> predictionRows = [];

  // Acquisition
  List<String> acquisitionHeader = [];
  List<List<dynamic>> acquisitionRows = [];

  bool connected = false;
  bool _isFetching = false; // cegah fetch bertumpuk

  static const _baseUrl = "http://192.168.4.1";

  @override
  void initState() {
    super.initState();
    // Fetch sekali saat halaman dibuka
    fetchData();
  }

  @override
  void dispose() {
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
        // Parse CSV → ambil header dari baris pertama, sisanya rows
        final parsedResults = _safeParseCsv(resResults.body);
        final parsedCaptures = _safeParseCsv(resCaptures.body);

        List<String> predHeader = [];
        List<List<dynamic>> predRows = [];
        if (parsedResults.isNotEmpty) {
          predHeader = parsedResults.first.map((e) => e.toString()).toList();
          predRows = parsedResults.length > 1
              ? parsedResults.sublist(1)
              : <List<dynamic>>[];
        }

        List<String> acqHeader = [];
        List<List<dynamic>> acqRows = [];
        if (parsedCaptures.isNotEmpty) {
          acqHeader = parsedCaptures.first.map((e) => e.toString()).toList();
          acqRows = parsedCaptures.length > 1
              ? parsedCaptures.sublist(1)
              : <List<dynamic>>[];
        }

        if (!mounted) {
          _isFetching = false;
          return;
        }
        setState(() {
          connected = true;
          predictionHeader = predHeader;
          predictionRows = predRows;
          acquisitionHeader = acqHeader;
          acquisitionRows = acqRows;
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

  List<List<dynamic>> _safeParseCsv(String csv) {
    try {
      if (csv.trim().isEmpty) return const [];
      return const CsvToListConverter(eol: '\n').convert(csv);
    } catch (_) {
      return const [];
    }
  }

  void _setDisconnected() {
    if (!mounted) return;
    setState(() {
      connected = false;
      predictionHeader = [];
      predictionRows = [];
      acquisitionHeader = [];
      acquisitionRows = [];
    });
  }

  Future<void> exportCSV({
    required List<String> header,
    required List<List<dynamic>> rows,
    required String fileName,
  }) async {
    if (header.isEmpty && rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data kosong, tidak bisa diunduh")),
        );
      }
      return;
    }

    final data = <List<dynamic>>[
      if (header.isNotEmpty) header,
      ...rows,
    ];
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
            content: Text('Storage: ${storage.toStringAsFixed(2)} %'),
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
            predictionHeader = [];
            predictionRows = [];
            acquisitionHeader = [];
            acquisitionRows = [];
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

  // Pastikan jumlah sel per baris = jumlah kolom header
  List<dynamic> _fitRowToHeader(List<dynamic> row, int headerLen) {
    final r = List<dynamic>.from(row);
    if (r.length > headerLen) return r.sublist(0, headerLen);
    if (r.length < headerLen) r.addAll(List.filled(headerLen - r.length, ''));
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Get Data"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _isFetching ? null : fetchData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchData, // tarik ke bawah di paling atas untuk refresh
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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

            // Prediction (header dari CSV)
            _buildTableSection(
              title: "Prediction Results",
              header: predictionHeader,
              rows: predictionRows,
              onDownload: () => exportCSV(
                header: predictionHeader,
                rows: predictionRows,
                fileName: "prediction_results",
              ),
            ),

            // Acquisition (header dari CSV)
            _buildTableSection(
              title: "Acquisition Results",
              header: acquisitionHeader,
              rows: acquisitionRows,
              onDownload: () => exportCSV(
                header: acquisitionHeader,
                rows: acquisitionRows,
                fileName: "acquisition_results",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSection({
    required String title,
    required List<String> header,
    required List<List<dynamic>> rows,
    required VoidCallback onDownload,
  }) {
    // ada data kalau rows tidak kosong
    final bool hasData = rows.isNotEmpty;

    // siapkan kolom (kalau header kosong tetapi ada rows, ambil dari panjang row pertama)
    final List<String> columns = header.isNotEmpty
        ? header
        : (hasData
            ? List<String>.generate(rows.first.length, (i) => 'Col ${i + 1}')
            : const <String>[]);

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

              // === Konten: TABEL jika ada data, kalau tidak tampilkan placeholder teks ===
              if (hasData)
                SizedBox(
                  height: 220,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
                        rows: rows.map((row) {
                          final cells = _fitRowToHeader(row, columns.length);
                          return DataRow(
                            cells: cells.map((cell) => DataCell(Text(cell.toString()))).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      "Tidak ada data untuk ditampilkan",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: hasData ? onDownload : null, // nonaktif kalau kosong
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

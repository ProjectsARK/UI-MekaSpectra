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

  @override
  void initState() {
    super.initState();
    // langsung cek data setiap 5 detik
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchData();
    });
    // panggilan awal
    fetchData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      final predRes =
          await http.get(Uri.parse("http://192.168.4.1/prediction")).timeout(const Duration(seconds: 3));
      final acqRes =
          await http.get(Uri.parse("http://192.168.4.1/acquisition")).timeout(const Duration(seconds: 3));

      if (predRes.statusCode == 200 && acqRes.statusCode == 200) {
        setState(() {
          predictionResults = List<List<dynamic>>.from(jsonDecode(predRes.body));
          acquisitionResults = List<List<dynamic>>.from(jsonDecode(acqRes.body));
          connected = true;
        });
      } else {
        setState(() {
          connected = false;
          predictionResults = [];
          acquisitionResults = [];
        });
      }
    } catch (e) {
      setState(() {
        connected = false;
        predictionResults = [];
        acquisitionResults = [];
      });
    }
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

    String csvData = const ListToCsvConverter().convert(data);
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

  @override
  Widget build(BuildContext context) {
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
            if (!connected)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red[100],
                child: const Text(
                  "Tidak terhubung ke alat.",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            _buildTableSection(
              title: "Prediction Results",
              columns: const ['Date', 'Result', 'Lt', 'At'],
              data: predictionResults,
              onDownload: () => exportCSV(
                [
                  ['Date', 'Result', 'Lt', 'At'],
                  ...predictionResults
                ],
                "prediction_results",
              ),
            ),
            _buildTableSection(
              title: "Acquisition Results",
              columns: const ['Date', 'Lt', 'At', 'Wavelength'],
              data: acquisitionResults,
              onDownload: () => exportCSV(
                [
                  ['Date', 'Lt', 'At', 'Wavelength'],
                  ...acquisitionResults
                ],
                "acquisition_results",
              ),
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
  // Tentukan jumlah baris minimal yang ingin ditampilkan (5)
  final int minRows = 5;
  // Jika data kosong, buat list 5 baris kosong
  final List<List<dynamic>> displayData = data.isEmpty
      ? List.generate(minRows, (_) => List.filled(columns.length, ''))
      : data;

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
              // Atur tinggi fixed supaya ada scroll vertikal jika isi banyak
              height: 220,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
                    rows: displayData.map((row) {
                      return DataRow(
                        cells: row.map((cell) => DataCell(Text(cell.toString()))).toList(),
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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class UpdateModelPage extends StatefulWidget {
  const UpdateModelPage({Key? key}) : super(key: key);

  @override
  State<UpdateModelPage> createState() => _UpdateModelPageState();
}

class _UpdateModelPageState extends State<UpdateModelPage> {
  static const String _baseUrl = "http://192.168.4.1";
  static const String _endpoint = "/update"; // server.on("/update"...)
  static const String _fieldName = "file";   // /update POST file = .bin

  final http.Client _client = http.Client();

  File? selectedFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _client.close(); // hentikan koneksi jika halaman ditutup
    super.dispose();
  }

  // Pull-to-refresh handler
  Future<void> _onRefresh() async {
    // Jika ingin ping device, kamu bisa tambahkan GET ke /info di sini
    // final res = await _client.get(Uri.parse("$_baseUrl/info")).timeout(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => selectedFile = null); // reset pilihan file
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );
    if (!mounted) return;

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      // Validasi sederhana: pastikan ekstensi .bin
      final name = file.path.split('/').last.toLowerCase();
      if (!name.endsWith('.bin')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File harus berekstensi .bin")),
        );
        return;
      }
      setState(() => selectedFile = file);
    }
  }

  void cancelSelection() {
    if (!mounted) return;
    setState(() => selectedFile = null);
  }

  Future<void> uploadModel() async {
    if (selectedFile == null || _isUploading) return;

    setState(() => _isUploading = true);
    try {
      final uri = Uri.parse("$_baseUrl$_endpoint");
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(_fieldName, selectedFile!.path),
      );

      final streamed = await _client.send(request);
      if (!mounted) return;

      final response = await http.Response.fromStream(streamed);
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Model uploaded successfully")),
        );
      } else {
        final bodySnippet = response.body.length > 200
            ? "${response.body.substring(0, 200)}..."
            : response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload model (${response.statusCode})\n$bodySnippet")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String> _fileInfo(File f) async {
    try {
      final bytes = await f.length();
      final mb = bytes / (1024 * 1024);
      final name = f.path.split('/').last;
      return "$name • ${mb.toStringAsFixed(2)} MB";
    } catch (_) {
      final name = f.path.split('/').last;
      return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Model"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _onRefresh, // refresh via ikon juga (opsional)
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      // ⬇️ RefreshIndicator agar bisa pull-to-refresh
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(), // tetap bisa ditarik meski konten pendek
          padding: const EdgeInsets.all(16),
          children: [
            // Card drop area
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isUploading ? null : pickFile,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.file_upload, size: 40),
                        const SizedBox(height: 12),
                        FutureBuilder<String>(
                          future: selectedFile == null ? null : _fileInfo(selectedFile!),
                          builder: (context, snap) {
                            final text = selectedFile == null
                                ? "Tap to choose .bin file"
                                : (snap.data ?? selectedFile!.path.split('/').last);
                            return Text(
                              text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            );
                          },
                        ),
                        if (selectedFile != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "(Tap to replace file)",
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              "Upload model (.bin) ke sensor melalui koneksi lokal dengan ukuran model max 1,5 mb.",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),

            const SizedBox(height: 16),

            // Tombol-tombol
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isUploading || selectedFile == null) ? null : cancelSelection,
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isUploading || selectedFile == null) ? null : uploadModel,
                    child: _isUploading
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Upload"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

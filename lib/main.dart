import 'package:flutter/material.dart';
import 'package:mekaspectra/core/app_routes.dart';
import 'package:mekaspectra/core/theme.dart';

// Halaman utama
import 'package:mekaspectra/pages/home_page.dart';

void main() {
  runApp(const MekaSpectraApp());
}

class MekaSpectraApp extends StatelessWidget {
  const MekaSpectraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MekaSpectra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // Routing awal
      initialRoute: AppRoutes.home,

      routes: {
        AppRoutes.home: (context) => const HomePage(),
        AppRoutes.getData: (context) => const GetDataPage(),
        AppRoutes.editConfig: (context) => const EditConfigPage(),
        AppRoutes.updateModel: (context) => const UpdateModelPage(),
      },
    );
  }
}

// =============================
// Placeholder halaman lainnya
// =============================
class GetDataPage extends StatelessWidget {
  const GetDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Data')),
      body: const Center(child: Text('Halaman Get Data')),
    );
  }
}

class EditConfigPage extends StatelessWidget {
  const EditConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Config')),
      body: const Center(child: Text('Halaman Edit Config')),
    );
  }
}

class UpdateModelPage extends StatelessWidget {
  const UpdateModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Model')),
      body: const Center(child: Text('Halaman Update Model')),
    );
  }
}

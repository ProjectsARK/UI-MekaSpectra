import 'package:flutter/material.dart';

// Import halaman tujuan
import 'get_data.dart';
import 'edit_config.dart';
import 'update_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bagian atas: logo + background segitiga
            Stack(
              children: [
                ClipPath(
                  clipper: TriangleClipper(),
                  child: Container(
                    color: Colors.white,
                    height: 150,
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  height: 150,
                  child: Text(
                    'MekaSpectra',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 48, // langsung angka biar nggak perlu AppTextSizes
                        ),
                  ),
                ),
              ],
            ),

            // Tombol menu
            Column(
              children: [
                _MenuButton(
                  text: 'Get Data',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GetDataPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _MenuButton(
                  text: 'Edit Config',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditConfigPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _MenuButton(
                  text: 'Update Model',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UpdateModelPage()),
                    );
                  },
                ),
              ],
            ),

            // Logo bawah
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Image.asset(
                    'assets/images/LogoBIOAI.png',
                    height: 80,
                  ),
                  Image.asset(
                    'assets/images/LogoUB.png',
                    height: 80,
                  ),
                  Image.asset(
                    'assets/images/LogoIFRI.png',
                    height: 80,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Komponen tombol menu
class _MenuButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _MenuButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          text
        ),
      ),
    );
  }
}

// Membuat bentuk segitiga atas
class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

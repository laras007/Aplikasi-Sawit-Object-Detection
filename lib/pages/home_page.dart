import 'package:flutter/material.dart';
import 'object_detection_page.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agrinas Palma Nusantara')),
      body: Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ObjectDetectionPage(),
                  ),
                );
              },
              child: const Text('Mulai Deteksi'),
            ),
            ElevatedButton(onPressed: () {}, child: const Text('Ambil Gambar')),
          ],
        ),
      ),
    );
  }
}

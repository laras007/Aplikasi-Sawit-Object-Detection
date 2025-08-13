import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
// import 'package:tflite/tflite.dart'; // Uncomment jika menggunakan tflite

class ObjectDetectionPage extends StatefulWidget {
  @override
  _ObjectDetectionPageState createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  bool _isDetecting = false;
  // List? _recognitions;

  @override
  void initState() {
    super.initState();
    _initCamera();
    // _loadModel();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _cameraController = CameraController(
        cameras![0],
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
      setState(() {});
      // _startDetection();
    }
  }

  // Future<void> _loadModel() async {
  //   await Tflite.loadModel(
  //     model: "assets/yolov5.tflite",
  //     labels: "assets/labels.txt",
  //   );
  // }

  @override
  void dispose() {
    _cameraController?.dispose();
    // Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deteksi Objek (YOLO)')),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_cameraController!),
                // TODO: Tambahkan widget untuk menampilkan hasil deteksi
              ],
            ),
    );
  }
}

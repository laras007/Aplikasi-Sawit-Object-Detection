import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ObjectDetectionPage extends StatefulWidget {
  @override
  _ObjectDetectionPageState createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isDetecting = false;
  List<Map<String, dynamic>> _recognitions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadModel();
      await _initCamera();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _cameraController = CameraController(
          cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        setState(() {});
        _cameraController!.startImageStream((CameraImage image) {
          if (!_isDetecting) {
            _isDetecting = true;
            _runModelOnFrame(image).then((recognitions) {
              setState(() {
                _recognitions = recognitions;
              });
              _isDetecting = false;
            });
          }
        });
      } else {
        throw Exception('Tidak ada kamera yang tersedia pada perangkat.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal inisialisasi kamera: ' + e.toString();
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      final labelsRaw = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/labels.txt');
      _labels = labelsRaw.split('\n');
    } catch (e) {
      throw Exception('Gagal load model atau label: ' + e.toString());
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _runModelOnFrame(CameraImage image) async {
    // 1. Konversi CameraImage (YUV420) ke RGB
    int width = image.width;
    int height = image.height;
    // Konversi YUV ke RGB (hanya untuk format YUV420)
    List<int> rgb = List.filled(width * height * 3, 0);
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final int index = y * width + x;
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        int r = (yp + (1.370705 * (vp - 128))).round();
        int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128))).round();
        int b = (yp + (1.732446 * (up - 128))).round();
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);
        rgb[index * 3] = r;
        rgb[index * 3 + 1] = g;
        rgb[index * 3 + 2] = b;
      }
    }

    // 2. Resize ke 640x640 (input model)
    // Sederhana: ambil center crop jika rasio tidak sama, lalu resize
    int inputSize = 640;
    List<double> imageInput = List.filled(inputSize * inputSize * 3, 0);
    double xScale = width / inputSize;
    double yScale = height / inputSize;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        int srcX = (x * xScale).floor();
        int srcY = (y * yScale).floor();
        int srcIdx = (srcY * width + srcX) * 3;
        int dstIdx = (y * inputSize + x) * 3;
        imageInput[dstIdx] = rgb[srcIdx] / 255.0;
        imageInput[dstIdx + 1] = rgb[srcIdx + 1] / 255.0;
        imageInput[dstIdx + 2] = rgb[srcIdx + 2] / 255.0;
      }
    }

    // 3. Buat input tensor [1, 640, 640, 3]
    var input = imageInput.reshape([1, inputSize, inputSize, 3]);

    // 4. Siapkan output tensor (output shape tergantung model, misal [1, N, 11] untuk 6 class)
    // Anda bisa cek output shape model Anda dengan _interpreter!.getOutputTensors()
    var outputShapes = _interpreter!.getOutputTensors().map((e) => e.shape).toList();
    var output = List.generate(outputShapes[0][1], (i) => List.filled(outputShapes[0][2], 0.0));
    var outputTensor = [output];

    // 5. Run inference
    _interpreter!.run(input, outputTensor);

    // 6. Post-processing: ambil bbox, conf, class
    List<Map<String, dynamic>> recognitions = [];
    double confThreshold = 0.4;
    for (var pred in outputTensor[0]) {
      double conf = pred[4];
      if (conf > confThreshold) {
        // YOLOv8: [x, y, w, h, conf, ...class_probs]
        double x = pred[0];
        double y = pred[1];
        double w = pred[2];
        double h = pred[3];
        int classIdx = 0;
        double maxProb = 0;
        for (int i = 5; i < pred.length; i++) {
          if (pred[i] > maxProb) {
            maxProb = pred[i];
            classIdx = i - 5;
          }
        }
        // Skala bbox ke ukuran preview kamera
        double left = (x - w / 2) * width / inputSize;
        double top = (y - h / 2) * height / inputSize;
        double boxW = w * width / inputSize;
        double boxH = h * height / inputSize;
        recognitions.add({
          'rect': Rect.fromLTWH(left, top, boxW, boxH),
          'label': _labels != null && classIdx < _labels!.length ? _labels![classIdx] : 'Class $classIdx',
          'confidence': conf,
        });
      }
    }
    return recognitions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deteksi Objek (YOLO)')),
      body: _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
          : _cameraController == null || !_cameraController!.value.isInitialized
              ? Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    CameraPreview(_cameraController!),
                    ..._recognitions.map(
                      (det) => Positioned(
                        left: det['rect'].left,
                        top: det['rect'].top,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Text(
                            det['label'],
                            style: TextStyle(
                              backgroundColor: Colors.red,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

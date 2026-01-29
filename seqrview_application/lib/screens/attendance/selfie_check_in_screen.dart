import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';

class SelfieCheckInScreen extends StatefulWidget {
  const SelfieCheckInScreen({super.key});

  @override
  State<SelfieCheckInScreen> createState() => _SelfieCheckInScreenState();
}

class _SelfieCheckInScreenState extends State<SelfieCheckInScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // Needed for blink/smile
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _instruction = "Position your face in the circle";
  bool _canCapture = false;

  // Liveness State
  bool _eyesOpenPreviously = true;
  int _blinkCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    setState(() => _isCameraInitialized = true);
    _startImageStream();
  }

  void _startImageStream() {
    _controller?.startImageStream((image) async {
      if (_isProcessing || _canCapture) return;
      _isProcessing = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) return;

        final faces = await _faceDetector.processImage(inputImage);
        _processFaces(faces);
      } catch (e) {
        debugPrint("Face detection error: $e");
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _processFaces(List<Face> faces) {
    if (faces.isEmpty) {
      setState(() => _instruction = "No face detected");
      return;
    }

    final face = faces.first;
    
    // 1. Check Centering (Simple check)
    // Assuming 640x480 or similar. Just checking if face is roughly centered.
    // Ideally we map coordinates, but for now we rely on user compliance + basic checks.
    
    // 2. Liveness: BLINK
    double? leftEye = face.leftEyeOpenProbability;
    double? rightEye = face.rightEyeOpenProbability;

    if (leftEye == null || rightEye == null) return;

    if (leftEye < 0.1 && rightEye < 0.1) {
      // Eyes Closed
       _eyesOpenPreviously = false;
    } else if (leftEye > 0.8 && rightEye > 0.8 && !_eyesOpenPreviously) {
      // Eyes Opened after being closed -> BLINK Detected!
      _eyesOpenPreviously = true;
      _blinkCount++;
    }

    if (_blinkCount >= 1) {
      setState(() {
        _instruction = "Liveness Verified! Hold still...";
        _canCapture = true;
      });
      _captureAndReturn();
    } else {
      setState(() => _instruction = "Blink your eyes to verify");
    }
  }

  Future<void> _captureAndReturn() async {
    try {
      await _controller?.stopImageStream();
      final file = await _controller?.takePicture();
      if (file != null && mounted) {
        Navigator.pop(context, file.path);
      }
    } catch (e) {
      debugPrint("Capture error: $e");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final rotationCompensation =
        (sensorOrientation + orientations[DeviceOrientation.portraitUp]! + 270) % 360;

    // Basic NV21 conversion logic (simplified for brevity)
    // For robust production use, correct format handling is needed.
    // Here we assume standard formats for FaceDetection on Flutter.
    
    final allBytes = WriteBuffer();
    for (finalPlane in image.planes) {
      allBytes.putUint8List(finalPlane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(rotationCompensation) ?? InputImageRotation.rotation0,
      format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen Camera
          SizedBox.expand(child: CameraPreview(_controller!)),
          
          // Overlay
          Center(
            child: Container(
              width: 300,
              height: 400, // Oval shape
              decoration: BoxDecoration(
                border: Border.all(color: _canCapture ? Colors.green : Colors.white, width: 4),
                borderRadius: BorderRadius.circular(200),
              ),
            ),
          ),

          // Instruction Text
          Positioned(
            top: 100,
            left: 0, right: 0,
            child: Text(
              _instruction ?? "",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 50, left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}

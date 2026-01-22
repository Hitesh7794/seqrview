import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/session_controller.dart';

class FaceMatchPlaceholderScreen extends StatefulWidget {
  final SessionController session;
  const FaceMatchPlaceholderScreen({super.key, required this.session});

  @override
  State<FaceMatchPlaceholderScreen> createState() => _FaceMatchPlaceholderScreenState();
}

class _FaceMatchPlaceholderScreenState extends State<FaceMatchPlaceholderScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: true, // For liveness (prob not fully used here but good practice)
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isFaceDetected = false;
  bool _loading = false;
  String? _error;
  CameraDescription? _frontCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-initialize camera on resume if needed (simplified handling)
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // 1. Request Permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() => _error = "Camera permission denied.");
        return;
      }

      // 2. Find Front Camera
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _frontCamera = front;

      // 3. Initialize Controller
      _controller = CameraController(
        front,
        ResolutionPreset.high, // High resolution often fixes stride/tint issues on Android
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      // 4. Start Image Stream for Face Detection
      await _controller!.startImageStream(_processCameraImage);

      setState(() {
        _isCameraInitialized = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = "Camera init error: $e");
    }
  }

  Future<void> _stopCamera() async {
    _controller?.stopImageStream();
    _controller?.dispose();
    _controller = null;
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || _loading || !mounted) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      // Simple liveness: Just check if any face is detected
      final hasFace = faces.isNotEmpty;
      
      if (mounted && hasFace != _isFaceDetected) {
         setState(() => _isFaceDetected = hasFace);
      }
    } catch (e) {
      // debugPrint("Face detect error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // --- Capture & Verify Logic ---
  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Pause stream to "freeze" UI and prevent new detections
      await _controller?.stopImageStream();
      
      // 2. Capture
      final XFile imageFile = await _controller!.takePicture();
      
      final kycUid = widget.session.kycSessionUid;
      if (kycUid == null) throw "KYC Session missing";

      // 3. Liveness Check (API)
      final liveResp = await widget.session.api.dio.post(
        '/api/kyc/face/liveness/',
        data: FormData.fromMap({
          "kyc_session_uid": kycUid,
          "selfie": await MultipartFile.fromFile(imageFile.path, filename: "selfie.jpg"),
        }),
      );
      final isLive = liveResp.data is Map && (liveResp.data['live'] == true);
      if (!isLive) throw "Liveness check failed. Please try again.";

      // 4. Face Match (API)
      await widget.session.api.dio.post(
        '/api/kyc/face/match/',
        data: FormData.fromMap({
          "kyc_session_uid": kycUid,
          "selfie": await MultipartFile.fromFile(imageFile.path, filename: "selfie.jpg"),
        }),
      );

      // Success
      if (mounted) await widget.session.bootstrap();
      
    } catch (e) {
      // Error handling
      String msg = e.toString();
      if (e is DioException) {
         msg = e.response?.data?['detail']?.toString() 
             ?? e.response?.data?['message']?.toString() 
             ?? "API Error ${e.response?.statusCode}";
      }
      if (mounted) {
         setState(() => _error = msg);
         // Resume stream to try again
         try {
           await _controller?.startImageStream(_processCameraImage);
         } catch (_) {} 
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- ML Kit Helpers ---
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null || _frontCamera == null) return null;

    final camera = _frontCamera!;
    final sensorOrientation = camera.sensorOrientation;
    
    // Rotation logic (simplified for portrait app)
    InputImageRotation? rotation;
    if (Platform.isIOS) {
       rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
       var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
       if (rotationCompensation == null) return null;
       if (camera.lensDirection == CameraLensDirection.front) {
         // Front camera rotation logic
         rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
       } else {
         rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
       }
       rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    // Format logic
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || 
       (Platform.isAndroid && format != InputImageFormat.nv21) || 
       (Platform.isIOS && format != InputImageFormat.bgra8888)) {
       return null; 
    }

    // Creating planes
    // Note: This is specific to `google_mlkit_face_detection` package expectation
    // We are passing raw bytes.
    if (image.planes.isEmpty) return null;
    
    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes), 
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow, // Main plane
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Colors
    final borderColor = _isFaceDetected ? const Color(0xFF10B981) : Colors.red; // Green : Red
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E11) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header
            Text(
              "Face Match",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Take one selfie. We'll check liveness first, then match with your Aadhaar photo.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            
            const Spacer(),
            
            // Camera Preview Circle
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. The Circular Camera Clip
                  Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black, // Placeholder if camera loading
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isCameraInitialized && _controller != null
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: CameraPreview(_controller!),
                          )
                        : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                  
                  // 2. The Border (Glow)
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: borderColor,
                        width: 4,
                      ),
                    ),
                  ),



                  // 4. Loading Overlay (during API call)
                  if (_loading)
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Detection Status Text
            Text(
              _loading 
                 ? "Verifying..." 
                 : (_isFaceDetected ? "Face Detected" : "Scanning environment..."),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: _isFaceDetected ? const Color(0xFF10B981) : Colors.blueAccent,
              ),
            ),
            
            const Spacer(),

            // Error Display
             if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Capture Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (_isFaceDetected && !_loading) ? _captureAndVerify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF222B45), // Dark Blueish
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text(
                    "Capture Selfie",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
             // Footer Label
            Padding(
               padding: const EdgeInsets.only(bottom: 16),
               child: Text(
                 "Securely verified by Liveness Detection AI",
                 style: TextStyle(
                   fontSize: 12, 
                   color: isDark ? Colors.grey[600] : Colors.grey[500]
                 ),
               ),
            ),
          ],
        ),
      ),
    );
  }
}

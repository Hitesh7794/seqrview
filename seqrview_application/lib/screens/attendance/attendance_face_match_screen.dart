import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/session_controller.dart';
import '../../widgets/global_support_button.dart';

class AttendanceFaceMatchScreen extends StatefulWidget {
  final SessionController session;
  final String assignmentId;
  final String activityType; // 'CHECK_IN' or 'CHECK_OUT'
  final double latitude;
  final double longitude;

  const AttendanceFaceMatchScreen({
    super.key, 
    required this.session,
    required this.assignmentId,
    required this.activityType,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AttendanceFaceMatchScreen> createState() => _AttendanceFaceMatchScreenState();
}

class _AttendanceFaceMatchScreenState extends State<AttendanceFaceMatchScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: true, 
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isFaceDetected = false;
  String _statusMessage = "Scanning environment...";
  bool _loading = false;
  String? _error;
  CameraDescription? _frontCamera;
  
  final GlobalKey _previewKey = GlobalKey();
  Uint8List? _frozenImage;

  bool get isDark => widget.session.isDark;

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
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() => _error = "Camera permission denied.");
        return;
      }

      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _frontCamera = front;

      _controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

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
      
      bool validFace = false;
      String statusMsg = "Scanning environment...";

      if (faces.isNotEmpty) {
        if (faces.length > 1) {
           statusMsg = "Multiple faces detected. Only one allowed.";
           validFace = false;
        } else {
           final face = faces.first;
           final bbox = face.boundingBox;
           final imgSize = inputImage.metadata?.size ?? const Size(1, 1);
        
           final imgCenterX = imgSize.width / 2;
           final imgCenterY = imgSize.height / 2;
        
           final faceCenterX = bbox.center.dx;
           final faceCenterY = bbox.center.dy;
        
           final diffX = (faceCenterX - imgCenterX).abs();
           final diffY = (faceCenterY - imgCenterY).abs();
        
           final faceWidth = bbox.width;
           final tilt = face.headEulerAngleZ; 
        
           final relativeDistX = diffX / imgSize.width;
           final relativeDistY = diffY / imgSize.height;
           final relativeSize = faceWidth / imgSize.width;

           if (imgSize.width < 100) {
              validFace = true;
              statusMsg = "Face Detected";
           } else if (tilt != null && tilt.abs() > 20) {
             statusMsg = "Hold Phone Upright";
           } else if (relativeSize < 0.20) {
             statusMsg = "Move Closer";
           } else if (relativeDistX > 0.35 || relativeDistY > 0.45) { 
             statusMsg = "Center Your Face";
           } else {
             validFace = true;
             statusMsg = "Face Detected";
           }
        }
      } else {
        statusMsg = "No Face Detected";
      }
      
      if (mounted) {
         if (validFace != _isFaceDetected || _statusMessage != statusMsg) {
             setState(() {
               _isFaceDetected = validFace;
               _statusMessage = statusMsg;
             });
         }
      }
    } catch (e) {
      // ignore
    } finally {
      _isProcessing = false;
    }
  }

  Future<Uint8List?> _capturePreviewSnapshot() async {
    try {
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage(pixelRatio: 3.0); 
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      
      if (mounted && pngBytes != null) {
        setState(() => _frozenImage = pngBytes);
      }
      return pngBytes;
    } catch (e) {
      return null;
    }
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_loading) return;

    final snapshotBytes = await _capturePreviewSnapshot();
    if (snapshotBytes == null) {
      if (mounted) setState(() => _error = "Failed to capture image.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _controller?.stopImageStream();
      
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/attendance_selfie_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(snapshotBytes);
      
      if (widget.activityType == 'CHECK_IN') {
        await widget.session.api.checkIn(
          widget.assignmentId, 
          widget.latitude, 
          widget.longitude, 
          tempFile.path
        );
      } else {
        await widget.session.api.checkOut(
          widget.assignmentId, 
          widget.latitude, 
          widget.longitude, 
          tempFile.path
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      String msg = e.toString().replaceAll("Exception: ", "");
      if (mounted) {
        setState(() {
          _error = msg;
          _frozenImage = null; 
        });
        
        try {
          await _controller?.startImageStream(_processCameraImage);
        } catch (_) {} 
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null || _frontCamera == null) return null;

    final camera = _frontCamera!;
    final sensorOrientation = camera.sensorOrientation;
    
    InputImageRotation? rotation;
    if (Platform.isIOS) {
       rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
       var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
       if (rotationCompensation == null) return null;
       if (camera.lensDirection == CameraLensDirection.front) {
         rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
       } else {
         rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
       }
       rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || 
       (Platform.isAndroid && format != InputImageFormat.nv21) || 
       (Platform.isIOS && format != InputImageFormat.bgra8888)) {
       return null; 
    }

    if (image.planes.isEmpty) return null;
    
    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes), 
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
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
    final borderColor = _isFaceDetected ? const Color(0xFF10B981) : Colors.red;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E11) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.activityType == 'CHECK_IN' ? "Check-In Verification" : "Check-Out Verification",
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          GlobalSupportButton(isDark: isDark),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Please center your face in the circle for identity verification.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            
            const Spacer(),
            
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _isCameraInitialized && _controller != null
                            ? RepaintBoundary(
                                key: _previewKey,
                                child: SizedBox(
                                  width: 280, 
                                  height: 280,
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _controller!.value.previewSize!.height, 
                                      height: _controller!.value.previewSize!.width,
                                      child: CameraPreview(_controller!),
                                    ),
                                  ),
                                ),
                              )
                            : const Center(child: CircularProgressIndicator(color: Colors.white)),
                        
                        if (_frozenImage != null)
                          Image.memory(
                            _frozenImage!,
                            fit: BoxFit.cover,
                            width: 280,
                            height: 280,
                          ),
                      ],
                    ),
                  ),
                  
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

                  if (_loading)
                    Container(
                      width: 280,
                      height: 280,
                      decoration: const BoxDecoration(
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

            Text(
              _loading ? "Verifying Identity..." : _statusMessage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: _isFaceDetected ? const Color(0xFF10B981) : Colors.blueAccent,
              ),
            ),
            
            const Spacer(),

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

            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (_isFaceDetected && !_loading) ? _captureAndVerify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF222B45), 
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text(
                    "Verify & Proceed",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

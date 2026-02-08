import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/onboarding_stage.dart';
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
  String _statusMessage = "Scanning environment...";
  bool _loading = false;
  String? _error;
  CameraDescription? _frontCamera;
  
  // Snapshot State
  final GlobalKey _previewKey = GlobalKey();
  Uint8List? _frozenImage;

  // Theme State
  bool get isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }
  
  Future<Uint8List?> _capturePreviewSnapshot() async {
    try {
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      // Capture the current frame as an image with higher pixel ratio for better quality
      final image = await boundary.toImage(pixelRatio: 3.0); 
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      
      if (mounted && pngBytes != null) {
        setState(() => _frozenImage = pngBytes);
      }
      return pngBytes;
    } catch (e) {
      debugPrint("Snapshot error: $e");
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_update);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_update);
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
      
      bool validFace = false;
      String statusMsg = "Scanning environment...";

      if (faces.isNotEmpty) {
        final face = faces.first;
        final bbox = face.boundingBox;
        final imgSize = inputImage.metadata?.size ?? const Size(1, 1);
        
        // Simple validation logic
        // 1. Center check (Horizontal)
        final imgCenterX = imgSize.width / 2;
        final imgCenterY = imgSize.height / 2;
        
        final faceCenterX = bbox.center.dx;
        final faceCenterY = bbox.center.dy;
        
        final diffX = (faceCenterX - imgCenterX).abs();
        final diffY = (faceCenterY - imgCenterY).abs();
        
        // 2. Size check (Fill roughly 20-30% of width)
        final faceWidth = bbox.width;
        
        // 3. Tilt Check (Horizontal rotation/tilt)
        final tilt = face.headEulerAngleZ; // rotation around Z axis
        
        // Thresholds (tunable)
        final relativeDistX = diffX / imgSize.width;
        final relativeDistY = diffY / imgSize.height; // Vertical deviation
        final relativeSize = faceWidth / imgSize.width;

        // SKIP validation if image size is tiny (metadata missing) to prevent lock-out
        if (imgSize.width < 100) {
           validFace = true;
           statusMsg = "Face Detected";
        } else if (tilt != null && tilt.abs() > 20) {
          statusMsg = "Hold Phone Upright";
        } else if (relativeSize < 0.20) {
          statusMsg = "Move Closer";
        } else if (relativeDistX > 0.35 || relativeDistY > 0.45) { // Relaxed: 35% X, 45% Y deviation
          statusMsg = "Center Your Face";
        } else {
          validFace = true;
          statusMsg = "Face Detected";
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
      // debugPrint("Face detect error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // --- Error Dialog Helper ---
  void _showErrorDialog({
      required String title,
      required String message,
      required IconData icon,
      required Color color,
      bool isSessionExpired = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isSessionExpired) {
                widget.session.setStage(OnboardingStage.chooseKycMethod);
              }
            },
            child: Text(
              isSessionExpired ? "Restart KYC" : "Try Again",
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- Capture & Verify Logic ---
  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_loading) return;

    // 1. VISUAL FREEZE: Capture the current preview frame immediately as a SNAPSHOT
    // This ensures what the user sees is what we send.
    final snapshotBytes = await _capturePreviewSnapshot();
    
    if (snapshotBytes == null) {
      if (mounted) setState(() => _error = "Failed to capture image. Please try again.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 2. Pause stream to prevent new detections
      await _controller?.stopImageStream();
      
      // 3. Write Snapshot to Temp File
      // We use the snapshot bytes instead of taking a new picture
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(snapshotBytes);
      
      final kycUid = widget.session.kycSessionUid;
      if (kycUid == null) throw "KYC Session missing";

      // 4. Liveness Check (API) - 30s timeout
      final liveResp = await widget.session.api.dio.post(
        '/api/kyc/face/liveness/',
        data: FormData.fromMap({
          "kyc_session_uid": kycUid,
          "selfie": await MultipartFile.fromFile(tempFile.path, filename: "selfie.png"),
        }),
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      final isLive = liveResp.data is Map && (liveResp.data['live'] == true);
      if (!isLive) throw "Liveness check failed. Please try again.";

      // 5. Face Match (API) - 30s timeout
      await widget.session.api.dio.post(
        '/api/kyc/face/match/',
        data: FormData.fromMap({
          "kyc_session_uid": kycUid,
          "selfie": await MultipartFile.fromFile(tempFile.path, filename: "selfie.png"),
        }),
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      // Success
      if (mounted) await widget.session.bootstrap();
      
    } catch (e) {
      // Error handling
      String msg = e.toString();
      String title = "System Error";
      IconData icon = Icons.error_outline;
      Color color = Colors.red;
      bool isSessionExpired = false;

      if (e is DioException) {
         final statusCode = e.response?.statusCode;
         final data = e.response?.data;
         
         msg = data?['detail']?.toString() 
             ?? data?['message']?.toString() 
             ?? "API Error $statusCode";

         if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
            title = "Verification Provider Error";
            msg = "The verification service is temporarily busy or unreachable. Please try again in a moment.";
            icon = Icons.cloud_off_rounded;
            color = Colors.orange;

         } else if (statusCode == 400 || statusCode == 422) {
            title = "Verification Failed";
            
            // Check for Max Attempts (which returns 400 from backend)
            if (msg.contains("Maximum face match attempts reached")) {
                title = "Verification Failed";
                icon = Icons.gpp_bad_rounded;
                color = Colors.red;
                isSessionExpired = true;
            } else {
                // Clean up raw Surepass errors
                if (msg.contains("Surepass") && msg.contains("422")) {
                   msg = "Face verification failed. Please try again with better lighting.";
                }
                icon = Icons.face_retouching_off_rounded;
                color = Colors.orange;
            }
         } else if (msg.toLowerCase().contains("session expired") || 
                    msg.toLowerCase().contains("invalid session") ||
                    statusCode == 404) {
            title = "Session Expired";
            msg = "Your KYC session has expired for security reasons. Please restart the process.";
            icon = Icons.timer_off_rounded;
            isSessionExpired = true;
         } else if (statusCode == 429) {
            title = "Verification Failed";
            msg = "Maximum face match attempts reached. For security, this session has been cleared. Please restart verification.";
            icon = Icons.gpp_bad_rounded;
            color = Colors.red;
            isSessionExpired = true; 
         }
      }

      if (mounted) {
         setState(() {
           _error = msg;
           _frozenImage = null; // Unfreeze UI on error
         });

         // Show the new user-friendly dialog
         _showErrorDialog(
           title: title,
           message: msg,
           icon: icon,
           color: color,
           isSessionExpired: isSessionExpired,
         );
         
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
    // final isDark = theme.brightness == Brightness.dark; // Use session.isDark getter instead
    
    // Colors
    final borderColor = _isFaceDetected ? const Color(0xFF10B981) : Colors.red; // Green : Red
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E11) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Image.asset(
          'assets/images/logo.png',
          height: 32,
        ),
        actions: [
          IconButton(
            onPressed: () => widget.session.logout(),
            icon: Icon(Icons.logout, color: textColor),
            tooltip: 'Logout',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            
            // Title moved to Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Face Match",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Take one selfie. We'll check liveness first, then match with your Aadhaar photo.",
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Live Camera View
                        _isCameraInitialized && _controller != null
                            ? RepaintBoundary(
                                key: _previewKey,
                                child: SizedBox(
                                  width: 280, 
                                  height: 280,
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      // Swap width/height for Portrait mode to ensure correct coverage
                                      width: _controller!.value.previewSize!.height, 
                                      height: _controller!.value.previewSize!.width,
                                      child: CameraPreview(_controller!),
                                    ),
                                  ),
                                ),
                              )
                            : const Center(child: CircularProgressIndicator(color: Colors.white)),
                        
                        // Frozen Screenshot Overlay (Visual Feedback Only)
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
                 : _statusMessage,
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
            // const SizedBox(height: 16),
            //  // Footer Label
            // Padding(
            //    padding: const EdgeInsets.only(bottom: 16),
            //    child: Text(
            //      "Securely verified by Liveness Detection AI",
            //      style: TextStyle(
            //        fontSize: 12, 
            //        color: isDark ? Colors.grey[600] : Colors.grey[500]
            //      ),
            //    ),
            // ),
          ],
        ),
      ),
    );
  }
}

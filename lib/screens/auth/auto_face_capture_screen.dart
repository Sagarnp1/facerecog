import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:async';

/// A full-screen camera that auto-captures 5 face photos in one session.
/// Opens camera once, shows live preview with pose instructions,
/// auto-captures with a countdown, and returns all 5 images.
class AutoFaceCaptureScreen extends StatefulWidget {
  const AutoFaceCaptureScreen({super.key});

  @override
  State<AutoFaceCaptureScreen> createState() => _AutoFaceCaptureScreenState();
}

class _AutoFaceCaptureScreenState extends State<AutoFaceCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  int _currentPose = 0;
  int _countdown = 0;
  final List<File> _capturedImages = [];
  Timer? _countdownTimer;
  String _statusMessage = 'Initializing camera...';
  bool _showFlash = false;

  final List<_PoseInstruction> _poses = const [
    _PoseInstruction(
      title: 'Look Straight',
      instruction: 'Look directly at the camera',
      icon: Icons.face,
    ),
    _PoseInstruction(
      title: 'Turn Left',
      instruction: 'Turn your head slightly to the left',
      icon: Icons.arrow_back,
    ),
    _PoseInstruction(
      title: 'Turn Right',
      instruction: 'Turn your head slightly to the right',
      icon: Icons.arrow_forward,
    ),
    _PoseInstruction(
      title: 'Look Up',
      instruction: 'Tilt your head up slightly',
      icon: Icons.arrow_upward,
    ),
    _PoseInstruction(
      title: 'Look Down',
      instruction: 'Tilt your head down slightly',
      icon: Icons.arrow_downward,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera found');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _statusMessage = '';
        });
        // Start the capture sequence after a brief delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _startCountdown();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Camera error: $e');
      }
    }
  }

  void _startCountdown() {
    if (!mounted || _currentPose >= _poses.length) return;

    setState(() {
      _countdown = 3;
      _isCapturing = false;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        _captureCurrentPose();
      }
    });
  }

  Future<void> _captureCurrentPose() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile picture = await _cameraController!.takePicture();
      final directory = await getTemporaryDirectory();
      final imagePath = path.join(
        directory.path,
        'face_capture_${_currentPose}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final File savedFile = await File(picture.path).copy(imagePath);

      if (!mounted) return;

      // Flash effect
      setState(() => _showFlash = true);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _showFlash = false);

      _capturedImages.add(savedFile);

      if (_currentPose < _poses.length - 1) {
        // Move to next pose
        setState(() {
          _currentPose++;
          _isCapturing = false;
        });
        // Brief pause to read instruction, then start countdown
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _startCountdown();
        });
      } else {
        // All done! Return the images
        setState(() {
          _statusMessage = 'All photos captured!';
          _isCapturing = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(_capturedImages);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _statusMessage = 'Capture failed, retrying...';
        });
        // Retry after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _startCountdown();
        });
      }
    }
  }

  void _retakeAll() {
    _countdownTimer?.cancel();
    // Delete captured files
    for (var file in _capturedImages) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    setState(() {
      _capturedImages.clear();
      _currentPose = 0;
      _isCapturing = false;
      _countdown = 0;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startCountdown();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isCameraReady ? _buildCameraView() : _buildLoadingView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Center(
          child: AspectRatio(
            aspectRatio: 1 / _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),

        // Flash overlay
        if (_showFlash)
          Container(color: Colors.white.withOpacity(0.8)),

        // Top bar with close button and progress
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                const SizedBox(width: 8),
                // Progress dots
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _capturedImages.length
                              ? Colors.green
                              : i == _currentPose
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                        ),
                        child: Center(
                          child: i < _capturedImages.length
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: i == _currentPose
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 36), // Balance the close button
              ],
            ),
          ),
        ),

        // Bottom instruction panel
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pose icon
                Icon(
                  _poses[_currentPose].icon,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 8),
                // Pose title
                Text(
                  '${_currentPose + 1}/5 - ${_poses[_currentPose].title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Instruction
                Text(
                  _poses[_currentPose].instruction,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Countdown or status
                if (_countdown > 0)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        '$_countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (_isCapturing)
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                else
                  const SizedBox(height: 72),

                const SizedBox(height: 16),

                // Retake button (only show after first capture)
                if (_capturedImages.isNotEmpty)
                  TextButton.icon(
                    onPressed: _retakeAll,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text(
                      'Start Over',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Oval face guide overlay
        Center(
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _countdown > 0
                      ? Colors.white.withOpacity(0.5)
                      : _isCapturing
                          ? Colors.green.withOpacity(0.8)
                          : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(110),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PoseInstruction {
  final String title;
  final String instruction;
  final IconData icon;

  const _PoseInstruction({
    required this.title,
    required this.instruction,
    required this.icon,
  });
}

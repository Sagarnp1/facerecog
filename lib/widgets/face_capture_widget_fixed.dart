import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/face_recognition_service.dart';

class FaceCaptureWidget extends StatefulWidget {
  final Function(List<double>) onComplete;

  const FaceCaptureWidget({
    super.key,
    required this.onComplete,
  });

  @override
  State<FaceCaptureWidget> createState() => _FaceCaptureWidgetState();
}

class _FaceCaptureWidgetState extends State<FaceCaptureWidget> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  FaceRecognitionService? _faceService;
  
  FaceCaptureStep _currentStep = FaceCaptureStep.center;
  int _currentStepIndex = 0;
  List<String> _capturedImages = [];
  bool _isCapturing = false;
  bool _isProcessing = false;
  String? _feedbackMessage;

  final List<FaceCaptureStep> _steps = [
    FaceCaptureStep.center,
    FaceCaptureStep.left,
    FaceCaptureStep.right,
    FaceCaptureStep.up,
    FaceCaptureStep.down,
    FaceCaptureStep.smile,
  ];

  @override
  void initState() {
    super.initState();
    print('FaceCaptureWidget: Initializing camera...');
    _initializeCamera();
    _faceService = FaceRecognitionService();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceService?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      print('FaceCaptureWidget: Getting available cameras...');
      _cameras = await availableCameras();
      print('FaceCaptureWidget: Found ${_cameras?.length ?? 0} cameras');
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Use front camera for face capture
        final frontCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        print('FaceCaptureWidget: Using camera: ${frontCamera.name}');
        
        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        print('FaceCaptureWidget: Initializing camera controller...');
        await _cameraController!.initialize();
        print('FaceCaptureWidget: Camera initialized successfully');
        
        if (mounted) {
          setState(() {
            _feedbackMessage = 'Camera ready! ${_currentStep.instruction}';
          });
        }
      } else {
        print('FaceCaptureWidget: No cameras available');
        setState(() {
          _feedbackMessage = 'No camera available on this device';
        });
      }
    } catch (e) {
      print('FaceCaptureWidget: Camera initialization error: $e');
      setState(() {
        _feedbackMessage = 'Camera not available: ${e.toString()}';
      });
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _feedbackMessage = 'Capturing...';
    });

    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath = path.join(
        directory.path,
        'face_${_currentStepIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Take picture
      final XFile picture = await _cameraController!.takePicture();
      await picture.saveTo(imagePath);

      // Validate face position (simplified - in real app you'd use ML Kit)
      await _validateAndSaveImage(imagePath);

    } catch (e) {
      print('Capture error: $e');
      setState(() {
        _feedbackMessage = 'Failed to capture image. Try again.';
        _isCapturing = false;
      });
    }
  }

  Future<void> _validateAndSaveImage(String imagePath) async {
    try {
      // In a real implementation, you would use the face recognition service
      // to validate the face position matches the current step
      // For now, we'll simulate validation
      await Future.delayed(const Duration(milliseconds: 500));

      _capturedImages.add(imagePath);

      if (_currentStepIndex < _steps.length - 1) {
        setState(() {
          _currentStepIndex++;
          _currentStep = _steps[_currentStepIndex];
          _feedbackMessage = 'Great! Now ${_currentStep.instruction.toLowerCase()}';
          _isCapturing = false;
        });
      } else {
        // All steps completed, generate embeddings
        await _generateEmbeddings();
      }
    } catch (e) {
      print('Validation error: $e');
      setState(() {
        _feedbackMessage = 'Please try again';
        _isCapturing = false;
      });
    }
  }

  Future<void> _generateEmbeddings() async {
    setState(() {
      _isProcessing = true;
      _feedbackMessage = 'Processing face data...';
    });

    try {
      final embeddings = await _faceService!.generateEmbeddings(_capturedImages);
      
      // Clean up temporary images
      for (String imagePath in _capturedImages) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        _feedbackMessage = 'Face registration complete!';
        _isProcessing = false;
      });

      // Call completion callback
      widget.onComplete(embeddings);

    } catch (e) {
      print('Embedding generation error: $e');
      setState(() {
        _feedbackMessage = 'Failed to process face data. Please try again.';
        _isProcessing = false;
      });
    }
  }

  void _retakeCurrentStep() {
    if (_currentStepIndex > 0 && _capturedImages.isNotEmpty) {
      // Remove the last captured image
      final lastImage = _capturedImages.removeLast();
      File(lastImage).delete().catchError((e) {
        print('Delete error: $e');
        return File(''); // Return a dummy file
      });
      
      setState(() {
        _currentStepIndex--;
        _currentStep = _steps[_currentStepIndex];
        _feedbackMessage = _currentStep.instruction;
      });
    }
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          
          // Face guide overlay
          Positioned.fill(
            child: CustomPaint(
              painter: FaceGuidePainter(),
            ),
          ),
          
          // Step indicator
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentStepIndex + 1} of ${_steps.length}: ${_currentStep.title}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _capturedImages.length == _steps.length && !_isProcessing;
    
    return Column(
      children: [
        // Camera Preview
        Expanded(
          flex: 3,
          child: _buildCameraPreview(),
        ),
        const SizedBox(height: 16),

        // Instruction Text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                isComplete ? 'Face Registration Complete!' : _currentStep.instruction,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isComplete ? Colors.green : Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              if (_feedbackMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _feedbackMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Progress Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _steps.asMap().entries.map((entry) {
            final index = entry.key;
            final isCompleted = index < _capturedImages.length;
            final isCurrent = index == _currentStepIndex;
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? Colors.green
                    : isCurrent
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Action Buttons
        if (!isComplete && !_isProcessing) ...[
          Row(
            children: [
              if (_currentStepIndex > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _retakeCurrentStep,
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCapturing ? null : _captureImage,
                  child: _isCapturing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Capture'),
                ),
              ),
            ],
          ),
        ] else if (_isProcessing) ...[
          const Center(
            child: CircularProgressIndicator(),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Face registration completed! You can now create your account.',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw face guide oval
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3;
    
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

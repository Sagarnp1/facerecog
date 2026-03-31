/// Example integration code for using Python backend in Flutter registration screen
/// 
/// This file demonstrates how to modify your existing student_signup_screen.dart
/// to use the Python backend for face embedding generation instead of ML Kit.
/// 
/// INTEGRATION STEPS:
/// 
/// 1. Import the new services at the top of student_signup_screen.dart:
///    ```dart
///    import '../../services/python_backend_service.dart';
///    ```
///
/// 2. Add a PythonBackendService instance to your State class:
///    ```dart
///    class _StudentSignupScreenState extends State<StudentSignupScreen> {
///      late final PythonBackendService _pythonBackend;
///      
///      @override
///      void initState() {
///        super.initState();
///        // For registration, use network IP if server is on different machine
///        // For example: 'http://10.172.135.246:8000'
///        _pythonBackend = PythonBackendService(
///          registrationUrl: 'http://10.172.135.246:8000', // Change to network IP if needed
///        );
///      }
///    }
///    ```
///
/// 3. Replace the face capture callback to save image paths instead of embeddings:
///    Instead of calling ML Kit's generateEmbeddings, save the captured image paths.
///    
///    BEFORE (old code):
///    ```dart
///    void _onFaceCaptureComplete(List<double> embeddings) {
///      setState(() {
///        _faceEmbeddings = embeddings;
///      });
///    }
///    ```
///    
///    AFTER (new code):
///    ```dart
///    List<String>? _capturedImagePaths; // Add this to state variables
///    
///    void _onFaceCaptureComplete(List<String> imagePaths) {
///      setState(() {
///        _capturedImagePaths = imagePaths;
///      });
///    }
///    ```
///
/// 4. Modify face_capture_widget.dart to return image paths instead of generating embeddings:
///    Your FaceCaptureWidget should save the 5 captured images to temporary files
///    and return their paths. Example:
///    
///    ```dart
///    Future<void> _captureAndSaveImage() async {
///      final XFile? imageFile = await _controller?.takePicture();
///      if (imageFile != null) {
///        _capturedImagePaths.add(imageFile.path);
///        // Move to next step...
///      }
///    }
///    ```
///
/// 5. Update the _completeSignup method to send images to Python backend:
///    
///    ```dart
///    Future<void> _completeSignup() async {
///      if (!_formKey.currentState!.validate() || _capturedImagePaths == null) {
///        ScaffoldMessenger.of(context).showSnackBar(
///          const SnackBar(
///            content: Text('Please complete all steps including face registration'),
///            backgroundColor: Colors.red,
///          ),
///        );
///        return;
///      }
///    
///      try {
///        // Show loading indicator
///        showDialog(
///          context: context,
///          barrierDismissible: false,
///          builder: (context) => const Center(
///            child: CircularProgressIndicator(),
///          ),
///        );
///    
///        // Convert images to base64
///        final base64Images = await PythonBackendService.imageFilesToBase64(
///          _capturedImagePaths!
///        );
///    
///        // Send to Python backend
///        final result = await _pythonBackend.registerStudent(
///          fullName: _fullNameController.text.trim(),
///          rollNo: _rollNoController.text.trim(),
///          batch: _selectedYear.toString(),
///          faculty: _selectedDepartment!.name,
///          base64Images: base64Images,
///        );
///    
///        // Hide loading indicator
///        if (mounted) Navigator.of(context).pop();
///    
///        if (!result['success']) {
///          // Show error
///          if (mounted) {
///            ScaffoldMessenger.of(context).showSnackBar(
///              SnackBar(
///                content: Text(result['message'] ?? 'Failed to process face images'),
///                backgroundColor: Colors.red,
///              ),
///            );
///          }
///          return;
///        }
///    
///        // Get embeddings from Python backend
///        final embeddings = result['embeddings'] as List;
///    
///        // Now save to Firestore with embeddings
///        final authProvider = Provider.of<AuthProvider>(context, listen: false);
///    
///        final success = await authProvider.signUpStudentWithEmbeddings(
///          fullName: _fullNameController.text.trim(),
///          email: _emailController.text.trim(),
///          password: _passwordController.text,
///          rollNo: _rollNoController.text.trim(),
///          department: _selectedDepartment!,
///          year: _selectedYear!,
///          faceEmbeddings: embeddings, // This is now List<List<double>>
///        );
///    
///        if (success) {
///          if (mounted) {
///            ScaffoldMessenger.of(context).showSnackBar(
///              const SnackBar(
///                content: Text('Account created successfully!'),
///                backgroundColor: Colors.green,
///              ),
///            );
///            Navigator.of(context).popUntil((route) => route.isFirst);
///          }
///        } else {
///          if (mounted) {
///            ScaffoldMessenger.of(context).showSnackBar(
///              SnackBar(
///                content: Text(authProvider.error ?? 'Signup failed'),
///                backgroundColor: Colors.red,
///              ),
///            );
///          }
///        }
///      } catch (e) {
///        // Hide loading if showing
///        if (mounted && Navigator.canPop(context)) {
///          Navigator.of(context).pop();
///        }
///    
///        if (mounted) {
///          ScaffoldMessenger.of(context).showSnackBar(
///            SnackBar(
///              content: Text('Error: ${e.toString()}'),
///              backgroundColor: Colors.red,
///            ),
///          );
///        }
///      }
///    }
///    ```
///
/// 6. Update AuthProvider's signUpStudent method to save embeddings correctly:
///    
///    In auth_provider.dart, update the Firestore document structure:
///    
///    ```dart
///    await FirebaseFirestore.instance
///        .collection('students')
///        .doc(userCredential.user!.uid)
///        .set({
///      'full_name': fullName,
///      'roll_no': rollNo,
///      'batch': year.toString(),
///      'faculty': department.name,
///      'face_embeddings': faceEmbeddings, // List of 5 lists of 128 floats
///      'registration_date': FieldValue.serverTimestamp(),
///      'email': email,
///    });
///    ```
///
/// 7. Add error handling and retry logic:
///    
///    ```dart
///    // Before calling registerStudent, test connection
///    final connectionTest = await _pythonBackend.testConnection();
///    if (!connectionTest['success']) {
///      showDialog(
///        context: context,
///        builder: (context) => AlertDialog(
///          title: const Text('Connection Error'),
///          content: Text(
///            'Cannot connect to face recognition server.\n\n'
///            '${connectionTest['message']}\n\n'
///            'Please ensure the Python backend is running.'
///          ),
///          actions: [
///            TextButton(
///              onPressed: () => Navigator.pop(context),
///              child: const Text('OK'),
///            ),
///          ],
///        ),
///      );
///      return;
///    }
///    ```
///
/// FIRESTORE DATA STRUCTURE EXAMPLE:
/// 
/// After successful registration, the student document in Firestore will look like:
/// ```json
/// {
///   "full_name": "John Doe",
///   "roll_no": "2021CS001",
///   "batch": "2021",
///   "faculty": "Computer Science",
///   "email": "john@example.com",
///   "face_embeddings": [
///     [0.123, -0.456, 0.789, ... 128 floats], // Image 1 embedding
///     [0.234, -0.567, 0.890, ... 128 floats], // Image 2 embedding
///     [0.345, -0.678, 0.901, ... 128 floats], // Image 3 embedding
///     [0.456, -0.789, 0.012, ... 128 floats], // Image 4 embedding
///     [0.567, -0.890, 0.123, ... 128 floats], // Image 5 embedding
///   ],
///   "registration_date": Timestamp,
/// }
/// ```
///
/// IMPORTANT NOTES:
/// 
/// 1. Image Quality: Ensure captured images are high quality (at least 640x480)
/// 2. Lighting: Good lighting is essential for accurate face detection
/// 3. Face Position: Face should be clearly visible and frontal in images
/// 4. Network Configuration: For registration server on different machine,
///    update registrationUrl to the network IP address (e.g., 'http://10.172.135.246:8000')
/// 5. Timeout: Image processing may take 15-30 seconds for 5 images
/// 6. Error Messages: Python backend returns specific error messages for each image
///    that fails processing (e.g., "No face detected in image 3")

library registration_integration_guide;

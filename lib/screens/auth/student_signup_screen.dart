import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';
import 'dart:io';
import '../../services/auth_provider.dart';
import 'auto_face_capture_screen.dart';
import '../../services/python_backend_service.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';

class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key});

  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  Department? _selectedDepartment;
  int? _selectedYear;
  List<double>? _faceEmbeddings;
  List<File> _capturedImages = [];
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  final _backendService = PythonBackendService();

  @override
  void dispose() {
    _fullNameController.dispose();
    _rollNoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _completeSignup() async {
    if (!_formKey.currentState!.validate() || _capturedImages.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all steps including 5 face images'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Test backend connection first
      print('Testing backend connection to: ${_backendService.registrationBaseUrl}');
      final testResult = await _backendService.testConnection();
      print('Backend test result: $testResult');
      
      if (testResult['success'] != true) {
        throw Exception('Backend not reachable: ${testResult['message']}');
      }
      
      // Convert images to base64
      final imagePaths = _capturedImages.map((file) => file.path).toList();
      final base64Images = await PythonBackendService.imageFilesToBase64(imagePaths);
      
      // Generate embeddings from Python backend
      final result = await _backendService.registerStudent(
        fullName: _fullNameController.text.trim(),
        rollNo: _rollNoController.text.trim(),
        batch: _selectedYear.toString(),
        faculty: _selectedDepartment!.name,
        base64Images: base64Images,
      );
      
      if (result['success'] != true || result['embeddings'] == null) {
        throw Exception(result['message'] ?? 'Failed to generate face embeddings from backend');
      }

      // Convert embeddings to List<double> properly
      // Backend returns List<List<double>> (5 images x 512 dimensions each)
      // We need to flatten to single List<double>
      final dynamic embeddingsData = result['embeddings'];
      print('Embeddings type: ${embeddingsData.runtimeType}');
      
      List<double> embeddings = [];
      if (embeddingsData is List) {
        for (var item in embeddingsData) {
          if (item is List) {
            // Each image's embeddings - add them to the flat list
            for (var value in item) {
              embeddings.add((value as num).toDouble());
            }
          }
        }
      } else {
        throw Exception('Embeddings is not a list: ${embeddingsData.runtimeType}');
      }
      
      print('Received ${embeddings.length} total embeddings from backend (${embeddingsData.length} images)');
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final success = await authProvider.signUpStudent(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rollNo: _rollNoController.text.trim(),
        department: _selectedDepartment!,
        year: _selectedYear!,
        embeddings: embeddings,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to login or dashboard
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Signup failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onFaceCaptureComplete(List<double> embeddings) {
    setState(() {
      _faceEmbeddings = embeddings;
    });
  }

  Future<void> _openAutoCapture() async {
    final List<File>? result = await Navigator.of(context).push<List<File>>(
      MaterialPageRoute(
        builder: (context) => const AutoFaceCaptureScreen(),
      ),
    );

    if (result != null && result.length == 5) {
      setState(() {
        _capturedImages = result;
      });
    }
  }

  Widget _buildBasicInfoStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Full Name
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Roll Number
            TextFormField(
              controller: _rollNoController,
              decoration: const InputDecoration(
                labelText: 'Roll Number',
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your roll number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Department Dropdown
          DropdownButtonFormField<Department>(
            value: _selectedDepartment,
            decoration: const InputDecoration(
              labelText: 'Department',
              prefixIcon: Icon(Icons.domain),
            ),
            items: Department.values.map((dept) {
              return DropdownMenuItem(
                value: dept,
                child: Text(dept.displayName),
              );
            }).toList(),
            onChanged: (Department? value) {
              setState(() {
                _selectedDepartment = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select your department';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Year Dropdown
          DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: const InputDecoration(
              labelText: 'Year',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: [1, 2, 3, 4].map((year) {
              return DropdownMenuItem(
                value: year,
                child: Text('Year $year'),
              );
            }).toList(),
            onChanged: (int? value) {
              setState(() {
                _selectedYear = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select your year';
              }
              return null;
            },
          ),
        ],
      ),
    ));
  }

  Widget _buildPasswordStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Security Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Password Requirements
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Requirements:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• At least 8 characters long',
                style: TextStyle(color: Colors.blue.shade600),
              ),
              Text(
                '• Use a strong, unique password',
                style: TextStyle(color: Colors.blue.shade600),
              ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _buildFaceCaptureStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Face Registration',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture 5 images of your face from different angles',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Show captured images
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 5; i++)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: i < _capturedImages.length
                          ? Colors.green
                          : Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: i < _capturedImages.length
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _capturedImages[i],
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.camera_alt,
                          color: Colors.grey[400],
                        ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_capturedImages.length < 5) ...[
            const Icon(
              Icons.camera_alt,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap below to open camera and auto-capture 5 photos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openAutoCapture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open Camera & Capture All 5'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ] else ...[
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'All images captured successfully!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _capturedImages.clear();
                });
              },
              child: const Text('Retake All Images'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: i <= _currentStep
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildBasicInfoStep(),
                    _buildPasswordStep(),
                    _buildFaceCaptureStep(),
                  ],
                ),
              ),
            ),

            // Navigation Buttons
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        final isLastStep = _currentStep == 2;
                        final canProceed = _currentStep < 2 || _capturedImages.length == 5;
                        return ElevatedButton(
                          onPressed: authProvider.isLoading || !canProceed
                              ? null
                              : () {
                                  if (isLastStep) {
                                    _completeSignup();
                                  } else {
                                    if (_currentStep == 0 && !_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setState(() {
                                      _currentStep++;
                                    });
                                  }
                                },
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(isLastStep ? 'Create Account' : 'Next'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

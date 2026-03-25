import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart'; // Using real Firebase auth
import 'services/notification_service.dart';
import 'screens/auth/auth_wrapper.dart';
import 'utils/theme.dart';
import 'models/user_model.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Use default theme during loading to prevent UI rebuilding
          final theme = (authProvider.isLoading || authProvider.currentUser == null)
              ? AppTheme.getTheme(Department.BCT)
              : AppTheme.getTheme(authProvider.currentUser!.department);

          return MaterialApp(
            title: 'IOE Student Management',
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

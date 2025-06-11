import 'package:flutter/material.dart';
import 'homescreen_enhanced.dart'; // ✅ Updated import
import 'profilescreen.dart';
import 'grocery_list_screen.dart';
import 'barcode_scanner_screen.dart';
import 'services/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/email_verification_screen.dart'; // Import for EmailVerificationScreen
import 'package:google_fonts/google_fonts.dart';
import 'config/env_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY'),
  );
  try {
    EnvConfig.validateApiKeys();
    EnvConfig.printDebugInfo();
  } catch (e) {
    print('❌ Environment Error: $e');
  }
  runApp(const DiabetesMeApp());
}

class DiabetesMeApp extends StatelessWidget {
  const DiabetesMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diabetes&Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFAF0),
        primaryColor: const Color(0xFF7B4FFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF1EFFF),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.black87,
                displayColor: Colors.black87,
              ),
        ),
        cardColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF7B4FFF)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      themeMode: ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const MainAppScaffold(),
        '/email-verification': (context) => EmailVerificationScreen(email: ''),
        '/grocery': (context) => const GroceryListScreen(),
        '/scanner': (context) => const BarcodeScannerScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // Check if user is authenticated AND email confirmed
        final session = Supabase.instance.client.auth.currentSession;
        final user = Supabase.instance.client.auth.currentUser;
        
        if (session != null && user != null) {
          // Check if email is confirmed
          if (user.emailConfirmedAt != null) {
            return const MainAppScaffold();
          } else {
            // User exists but email not confirmed
            return EmailVerificationScreen(email: user.email ?? '');
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    EnhancedHomeScreen(), // ✅ Updated to use enhanced screen
    const GroceryListScreen(),
    const BarcodeScannerScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _tabs[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Grocery List',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'homescreen_enhanced.dart';
import 'profilescreen.dart';
import 'grocery_list_screen.dart';
import 'barcode_scanner_screen.dart';
import 'services/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/email_verification_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/env_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

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

class DiabetesMeApp extends StatefulWidget {
  const DiabetesMeApp({super.key});

  @override
  State<DiabetesMeApp> createState() => _DiabetesMeAppState();
}

class _DiabetesMeAppState extends State<DiabetesMeApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Handle app launch from deep link (when app is closed)
    try {
      final initialLink = await _appLinks.getInitialAppLink();
      if (initialLink != null) {
        print('📱 App launched with deep link: $initialLink');
        // Wait a bit for the app to fully initialize
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleDeepLink(initialLink);
        });
      }
    } catch (e) {
      print('❌ Error getting initial link: $e');
    }
    
    // Handle deep link when app is already running
    _linkSubscription = _appLinks.allUriLinkStream.listen(
      (Uri uri) {
        print('📱 Received deep link while app running: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('❌ Deep link error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) async {
    print('🔗 Processing deep link: $uri');
    print('🔗 Scheme: ${uri.scheme}, Host: ${uri.host}');
    print('🔗 Query parameters: ${uri.queryParameters}');
    
    if (uri.scheme == 'com.abhinavsrinivasan.diabetesme' && 
        uri.host == 'login-callback') {
      
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];
      final type = uri.queryParameters['type'];
      
      print('🔗 Access token present: ${accessToken != null}');
      print('🔗 Refresh token present: ${refreshToken != null}');
      print('🔗 Type: $type');
      
      if (type == 'signup' && accessToken != null && refreshToken != null) {
        await _handleEmailConfirmation(accessToken, refreshToken);
      } else if (type == 'recovery' && accessToken != null && refreshToken != null) {
        await _handlePasswordReset(accessToken, refreshToken);
      }
    }
  }

  Future<void> _handleEmailConfirmation(String accessToken, String refreshToken) async {
    try {
      print('🔄 Setting Supabase session for email confirmation...');
      
      final response = await Supabase.instance.client.auth.setSession(accessToken);
      
      if (response.session != null) {
        print('✅ Email confirmed and user logged in!');
        
        // Show confirmation success screen
        if (mounted && _navigatorKey.currentState != null) {
          _navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => EmailConfirmationSuccessScreen(
                onContinue: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
            ),
            (route) => false,
          );
        }
      } else {
        throw Exception('Failed to set session');
      }
      
    } catch (e) {
      print('❌ Error setting session: $e');
      _showErrorDialog('Error confirming email: $e');
    }
  }

  Future<void> _handlePasswordReset(String accessToken, String refreshToken) async {
    try {
      final response = await Supabase.instance.client.auth.setSession(accessToken);
      
      if (response.session != null) {
        print('🔄 Password reset session set');
        
        // Navigate to password reset screen (you can create this later)
        if (mounted && _navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Password reset link verified. Please update your password.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error setting recovery session: $e');
      _showErrorDialog('Error processing password reset: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (mounted && _navigatorKey.currentContext != null) {
      showDialog(
        context: _navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: const Text('Email Confirmation Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate back to login
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diabetes&Me',
      navigatorKey: _navigatorKey,
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

// FIXED: Updated Email Confirmation Success Screen
class EmailConfirmationSuccessScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const EmailConfirmationSuccessScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<EmailConfirmationSuccessScreen> createState() => _EmailConfirmationSuccessScreenState();
}

class _EmailConfirmationSuccessScreenState extends State<EmailConfirmationSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Start animations
    _scaleController.forward();
    _fadeController.forward();

    // Auto-proceed to home after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onContinue();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView( // FIX: Added SingleChildScrollView
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                           MediaQuery.of(context).padding.top,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Success Icon with Animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 100, // FIX: Reduced size
                        height: 100, // FIX: Reduced size
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(50), // FIX: Adjusted for new size
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 50, // FIX: Reduced size
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24), // FIX: Reduced spacing
                    
                    // Success Title
                    const Text(
                      'Email Confirmed!',
                      style: TextStyle(
                        fontSize: 24, // FIX: Reduced font size
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    
                    const SizedBox(height: 12), // FIX: Reduced spacing
                    
                    // Success Message
                    Text(
                      'Welcome to Diabetes&Me! Your account has been successfully verified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14, // FIX: Reduced font size
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    
                    const SizedBox(height: 32), // FIX: Reduced spacing
                    
                    // Progress Indicator
                    Column(
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                        ),
                        const SizedBox(height: 12), // FIX: Reduced spacing
                        Text(
                          'Taking you to your dashboard...',
                          style: TextStyle(
                            fontSize: 12, // FIX: Reduced font size
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32), // FIX: Reduced spacing
                    
                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      height: 48, // FIX: Reduced height
                      child: ElevatedButton(
                        onPressed: widget.onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Continue to App',
                          style: TextStyle(
                            fontSize: 14, // FIX: Reduced font size
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    EnhancedHomeScreen(),
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
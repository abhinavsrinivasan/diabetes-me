import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../features/auth/screens/forgot_password_screen.dart';
import '../../../features/auth/screens/email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
    
    // Load remembered credentials
    _loadRememberedCredentials();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedCredentials() async {
    final rememberedEmail = await _authService.getRememberedEmail();
    final rememberedPassword = await _authService.getRememberedPassword();
    final hasRememberMe = await _authService.hasRememberMe();

    if (rememberedEmail != null) {
      setState(() {
        _emailController.text = rememberedEmail;
        if (rememberedPassword != null) {
          _passwordController.text = rememberedPassword;
        }
        _rememberMe = hasRememberMe;
      });
    }
  }

  void _submit() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar("Please fill in all fields");
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      _showErrorSnackBar("Please enter a valid email address");
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorSnackBar("Password must be at least 6 characters");
      return;
    }

    setState(() => _loading = true);

    if (_isLogin) {
      // LOGIN
      final result = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe,
      );
      setState(() => _loading = false);
      if (result.isSuccess) {
        // Success: AuthWrapper will handle navigation
      } else if (result.needsEmailConfirmation && result.email != null) {
        // Always route to email verification if needed
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: result.email!),
          ),
        );
      } else {
        _showErrorSnackBar(result.errorMessage ?? "Login failed. Please try again.");
      }
    } else {
      // SIGNUP
      if (_nameController.text.trim().isEmpty) {
        setState(() => _loading = false);
        _showErrorSnackBar("Please enter your name");
        return;
      }
      final result = await _authService.signup(
        _emailController.text.trim(),
        _passwordController.text,
        name: _nameController.text.trim(),
      );
      setState(() => _loading = false);
      if (result.isSuccess) {
        _showSuccessSnackBar("Account created successfully!");
      } else if (result.needsEmailConfirmation && result.email != null) {
        // Always route to email verification if needed
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: result.email!),
          ),
        );
      } else {
        _showErrorSnackBar(result.errorMessage ?? "This email is already registered or an error occurred.");
      }
    }
  }

  bool _isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}


  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Top Section with Logo and Toggle
                  Expanded(
                    flex: 4,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        color: Colors.transparent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Your Official Logo
                            ClipRRect(
                              borderRadius: BorderRadius.circular(90),
                              child: Image.asset(
                                'assets/appicon.png',
                                width: 180,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A90E2),
                                      borderRadius: BorderRadius.circular(90),
                                    ),
                                    child: const Icon(
                                      Icons.local_dining,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 6),
                            
                            // App Name
                            const Text(
                              'Diabetes&Me',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B35),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your diabetes-friendly lifestyle companion',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            
                            // Sign In / Sign Up Toggle
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => _isLogin = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isLogin ? const Color(0xFFFF6B35) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Sign in',
                                        style: TextStyle(
                                          color: _isLogin ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _isLogin = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isLogin ? const Color(0xFFFF6B35) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Sign up',
                                        style: TextStyle(
                                          color: !_isLogin ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Section with Form
                  Expanded(
                    flex: 6,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Form Fields
                            if (!_isLogin) ...[
                              _buildTextField(
                                controller: _nameController,
                                label: 'Name',
                                icon: Icons.person_outline,
                                keyboardType: TextInputType.name,
                              ),
                            ],
                            
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            if (!_isLogin) ...[
                              _buildTextField(
                                controller: _phoneController,
                                label: 'Phone number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ],

                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),

                            // Remember Me Checkbox (only for login)
                            if (_isLogin) ...[
                              Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.9,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                      activeColor: const Color(0xFFFF6B35),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  Text(
                                    'Remember me',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: const Color(0xFFFF6B35),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            const SizedBox(height: 16),

                            // Submit Button
                            Container(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6B35),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? 'Sign In' : 'Sign Up',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ]
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
    );
  }
}


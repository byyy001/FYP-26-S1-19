import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'login_screen.dart'; // for navigation back

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = false;
  bool _isHoveringSignUp = false;
  bool _isHoveringGoogle = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                // Logo at top
                Center(
                  child: Image.asset(
                    'assets/images/LinkSentryLogoTop.png',
                    width: screenWidth * 0.6,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 30),
                // Join us Today and Sign Up (as two lines or side by side? wireframe shows "Join us Today" above "Sign Up")
                // We'll follow the wireframe: two separate texts stacked.
                Text(
                  'Join us Today',
                  style: TextStyle(
                    fontSize: isSmall ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: isSmall ? 20 : 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 30),
                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        style: const TextStyle(color: AppColors.primaryText),
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          labelStyle: const TextStyle(color: AppColors.secondaryText),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        style: const TextStyle(color: AppColors.primaryText),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          labelStyle: const TextStyle(color: AppColors.secondaryText),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Email
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: AppColors.primaryText),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: AppColors.secondaryText),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.primaryText),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: AppColors.secondaryText),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.primaryText),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: const TextStyle(color: AppColors.secondaryText),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.secondaryText,
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Agreement checkbox and terms
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                      activeColor: AppColors.primaryBlue,
                      checkColor: Colors.white,
                      side: const BorderSide(color: AppColors.secondaryText),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: const TextStyle(
                                color: AppColors.primaryPurple,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: AppColors.primaryPurple,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Sign Up button with gradient and hover
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoveringSignUp = true),
                  onExit: (_) => setState(() => _isHoveringSignUp = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.premiumGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isHoveringSignUp
                          ? [
                              BoxShadow(
                                color: AppColors.primaryPurple.withAlpha(102),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: AppColors.primaryPurple.withAlpha(77),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate() && _agreeToTerms) {
                          // TODO: Perform sign up
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sign Up tapped (demo)'),
                              backgroundColor: AppColors.primaryPurple,
                            ),
                          );
                        } else if (!_agreeToTerms) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You must agree to the terms'),
                              backgroundColor: AppColors.highRisk,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Already have an account? Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an ',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: Text(
                        'account?',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Sign up with Google button
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoveringGoogle = true),
                  onExit: (_) => setState(() => _isHoveringGoogle = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: _isHoveringGoogle
                          ? [
                              BoxShadow(
                                color: AppColors.primaryPurple.withAlpha(51),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Google Sign-Up
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Google Sign-Up (demo)'),
                            backgroundColor: AppColors.primaryBlue,
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.g_mobiledata,
                        color: Colors.white,
                        size: 28,
                      ),
                      label: const Text(
                        'Sign up with Google',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.transparent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
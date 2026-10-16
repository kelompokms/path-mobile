import 'package:flutter/material.dart';
import '../forgot_password/forgot_password_page.dart';
import '../register/register_page.dart';
import '../widgets/path_logo.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const Color primaryBlue = Color(0xFF4285F4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Logo PATH sementara
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: const PathLogo(width: 92, height: 106),
                    ),
                    const SizedBox(height: 52),

                    // Panel Login
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black54, width: 0.6),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(48),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(44, 84, 44, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Judul dan ikon profil
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Navigator.maybePop(context);
                                    },
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      size: 24,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 40,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'Login',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const CircleAvatar(
                                    radius: 19,
                                    backgroundColor: primaryBlue,
                                    child: Icon(
                                      Icons.person_outline,
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 38),

                              // Username / Email
                              const Text(
                                'Username / Email',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const _LoginInput(hintText: 'Joko Sutoyo'),

                              const SizedBox(height: 20),

                              // Password
                              const Text(
                                'Password',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const _LoginInput(
                                hintText: '**********',
                                obscureText: true,
                              ),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot password',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Tombol Sign in
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Login belum terhubung '
                                            'ke backend.',
                                          ),
                                        ),
                                      );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text(
                                    'Sign in',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Belum punya akun? Sign up',
                                    style: TextStyle(
                                      color: primaryBlue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  final String hintText;
  final bool obscureText;

  const _LoginInput({required this.hintText, this.obscureText = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black, fontSize: 11),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black, fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 5, bottom: 8),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black45),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: LoginPage.primaryBlue),
        ),
      ),
    );
  }
}

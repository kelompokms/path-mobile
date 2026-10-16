import 'package:flutter/material.dart';
import '../login/login_page.dart';
import '../widgets/path_logo.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

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

                    // Panel Register
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
                              // Judul halaman
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
                                      'New Account',
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

                              const Text(
                                'Username',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const _RegisterInput(hintText: 'Joko Sutoyo'),

                              const SizedBox(height: 24),

                              const Text(
                                'Email',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const _RegisterInput(
                                hintText: 'contoh@email.com',
                                keyboardType: TextInputType.emailAddress,
                              ),

                              const SizedBox(height: 24),

                              const Text(
                                'Password',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const _RegisterInput(
                                hintText: 'Masukkan password',
                                obscureText: true,
                              ),

                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pendaftaran belum terhubung '
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
                                    'Sign up',
                                    style: TextStyle(fontSize: 14),
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
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Sudah punya akun? Sign in',
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

class _RegisterInput extends StatelessWidget {
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;

  const _RegisterInput({
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black, fontSize: 12),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black54, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 6, bottom: 10),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black45),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: RegisterPage.primaryBlue),
        ),
      ),
    );
  }
}

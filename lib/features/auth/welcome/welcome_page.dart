import 'package:flutter/material.dart';
import '../login/login_page.dart';
import '../register/register_page.dart';
import '../widgets/path_logo.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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
                child: SizedBox(
                  width: double.infinity,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      // Logo PATH
                      // Logo PATH
                    Positioned(
                      left: 24,
                      top: 26,
                      child: const PathLogo(
                        width: 104,
                        height: 120,
                      ),
                    ),
                                        

                      // Tombol Welcome
                      Positioned(
                        top: constraints.maxHeight * 0.6875,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 196,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LoginPage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  elevation: 3,
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text(
                                  'Sign in',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: 196,
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryBlue,
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(
                                    color: Colors.black26,
                                    width: 0.7,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text(
                                  'Sign up',
                                  style: TextStyle(fontSize: 14),
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
            );
          },
        ),
      ),
    );
  }
}
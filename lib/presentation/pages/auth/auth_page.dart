import 'package:cardverses/presentation/blocs/auth/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'CV',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).animate().scale(delay: 200.ms, duration: 600.ms),
              const SizedBox(height: 32),
              Text(
                'CardVerses',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 8),
              Text(
                'Play UNO with friends online',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[400],
                    ),
              ).animate().fadeIn(delay: 500.ms),
              const Spacer(),
              _buildSignInButton(
                context: context,
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                color: Colors.white,
                textColor: Colors.black87,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.read<AuthBloc>().add(AuthSignInWithGoogle());
                },
              ).animate().slideY(delay: 600.ms, begin: 1),
              const SizedBox(height: 12),
              _buildSignInButton(
                context: context,
                label: 'Continue with Apple',
                icon: Icons.apple,
                color: Colors.black,
                textColor: Colors.white,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.read<AuthBloc>().add(AuthSignInWithApple());
                },
              ).animate().slideY(delay: 700.ms, begin: 1),
              const SizedBox(height: 12),
              _buildSignInButton(
                context: context,
                label: 'Play as Guest',
                icon: Icons.person_outline,
                color: Colors.grey[800]!,
                textColor: Colors.white,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.read<AuthBloc>().add(AuthSignInAsGuest());
                },
              ).animate().slideY(delay: 800.ms, begin: 1),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor, size: 28),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// lib/pages/login_page.dart
// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // <-- CAMBIO: Importar Provider
import '../providers/user_profile_provider.dart'; // <-- CAMBIO: Importar nuestro Provider

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Lógica para iniciar sesión
  Future<void> _login() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Iniciar sesión con Firebase Auth
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // 2. CAMBIO: Verificar que el usuario no sea nulo
      if (credential.user != null && mounted) {
        // 3. CAMBIO: Llamar al Provider para cargar los datos del usuario
        // Usamos Provider.of con listen: false dentro de una función
        final userProfileProvider =
            Provider.of<UserProfileProvider>(context, listen: false);
        await userProfileProvider.loadUserProfile(credential.user!);

        // 4. CAMBIO: Solo navegar al dashboard DESPUÉS de cargar el perfil
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Usuario o contraseña incorrectos.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Problema de conexión a internet. Intenta de nuevo.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo no es válido.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Demasiados intentos fallidos. Intenta más tarde.';
      } else {
        errorMessage = 'Ocurrió un error inesperado. Intenta de nuevo.';
      }

      if (mounted) {
        setState(() => _error = errorMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Ocurrió un error inesperado.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Lógica para restablecer la contraseña
  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty ||
        !_emailCtrl.text.trim().contains('@')) {
      if (mounted) {
        setState(() {
          _error =
              'Por favor, ingresa tu correo en el campo "Nombre de Usuario" para restablecer la contraseña.';
        });
      }
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Se ha enviado un correo para restablecer tu contraseña.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'No hay usuario registrado con ese correo.';
      } else {
        errorMessage = 'Error: ${e.message ?? "Intenta de nuevo."}';
      }
      if (mounted) {
        setState(() => _error = errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (El resto del método build se mantiene exactamente igual) ...
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/images/logo_tvt.jpg',
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40.0),
              Text(
                'INICIAR SESIÓN',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 30.0),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Nombre de Usuario',
                  hintText: 'ejemplo@corat.mx',
                  prefixIcon:
                      Icon(Icons.person_outline, color: colorScheme.primary),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),
              TextFormField(
                controller: _passCtrl,
                obscureText: !_isPasswordVisible,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon:
                      Icon(Icons.lock_outline, color: colorScheme.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu contraseña';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10.0),
              AnimatedOpacity(
                opacity: _error != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    _error ?? '',
                    style: TextStyle(color: colorScheme.error, fontSize: 14.0),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 15.0),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: colorScheme.primary))
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('ENTRAR'),
                      ),
              ),
              const SizedBox(height: 20.0),
              TextButton(
                onPressed: _loading ? null : _resetPassword,
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

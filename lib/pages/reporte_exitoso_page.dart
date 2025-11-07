// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Pantalla mostrada al finalizar el envío de un reporte.
/// Incluye animación de confirmación y un sonido corto de éxito.
class ReporteExitosoPage extends StatefulWidget {
  const ReporteExitosoPage({super.key});

  @override
  State<ReporteExitosoPage> createState() => _ReporteExitosoPageState();
}

class _ReporteExitosoPageState extends State<ReporteExitosoPage> {
  // 🎵 Controlador para reproducir sonidos locales
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // Reproducir sonido al entrar en la pantalla
    _playSuccessSound();

    // Regresar automáticamente al formulario después de 3 segundos
    Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  /// 🔊 Reproduce el sonido de éxito ubicado en assets/audio/success.mp3
  Future<void> _playSuccessSound() async {
    try {
      await _player.play(AssetSource('audio/success.mp3'));
    } catch (e) {
      debugPrint("⚠️ Error al reproducir sonido: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Animación de éxito
            Lottie.asset(
              'assets/animations/successfully.json',
              width: 200,
              height: 200,
              repeat: false,
            ),

            const SizedBox(height: 20),
            const Text(
              '¡Reporte Enviado!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Gracias por tu registro',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

// 📄 lib/pages/reporte_combustible_page.dart
// Página para registrar combustible por estación
// Autor: Alejandro Lázaro Bautista
// Departamento de Transmisión - CORAT
// ---------------------------------------------------
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ReporteCombustiblePage extends StatefulWidget {
  final String usuario; // correo o nombre del usuario logueado
  const ReporteCombustiblePage({super.key, required this.usuario});

  @override
  State<ReporteCombustiblePage> createState() => _ReporteCombustiblePageState();
}

class _ReporteCombustiblePageState extends State<ReporteCombustiblePage> {
  // --- Controladores de campos
  final TextEditingController _litrosTanqueController = TextEditingController();
  final TextEditingController _litrosReservaController =
      TextEditingController();

  // --- Estado de imágenes tomadas
  File? _fotoTanque;
  File? _fotoBidones;

  // --- Selector de planta
  String? _plantaSeleccionada;

  // --- Variables de control UI
  bool _enviando = false;

  // --- Reproductor de audio
  final AudioPlayer player = AudioPlayer();

  final List<String> _plantas = [
    'Periférico',
    'La Venta',
    'Boca del Cerro',
    'Cunduacán'
  ];

  // --- Método para tomar foto desde cámara
  Future<void> _tomarFoto(bool esTanque) async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        if (esTanque) {
          _fotoTanque = File(pickedFile.path);
        } else {
          _fotoBidones = File(pickedFile.path);
        }
      });
    }
  }

  // --- Método para enviar el reporte
  Future<void> _enviarReporte() async {
    // Validación inicial
    if (_plantaSeleccionada == null ||
        _litrosTanqueController.text.isEmpty ||
        _litrosReservaController.text.isEmpty ||
        _fotoTanque == null ||
        _fotoBidones == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Completa todos los campos y toma ambas fotos')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final fecha = DateTime.now().toIso8601String();

      // --- Subida de imágenes a Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('reportes_combustible/$_plantaSeleccionada/$fecha');

      final tanqueRef = storageRef.child('tanque.jpg');
      final bidonesRef = storageRef.child('bidones.jpg');

      await tanqueRef.putFile(_fotoTanque!);
      await bidonesRef.putFile(_fotoBidones!);

      final urlTanque = await tanqueRef.getDownloadURL();
      final urlBidones = await bidonesRef.getDownloadURL();

      // --- Guardado en Firestore
      await FirebaseFirestore.instance.collection('reportes_combustible').add({
        'usuario': widget.usuario,
        'planta': _plantaSeleccionada,
        'litros_tanque': _litrosTanqueController.text,
        'litros_reserva': _litrosReservaController.text,
        'foto_tanque': urlTanque,
        'foto_bidones': urlBidones,
        'fecha': fecha,
      });

      // --- Reproducir sonido
      await player.play(AssetSource('audio/success.mp3'));

      // --- Mostrar animación de éxito
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/successfully.json',
                  repeat: false,
                  width: 150,
                ),
                const SizedBox(height: 12),
                const Text(
                  "¡Reporte enviado con éxito!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );

        // Esperar antes de cerrar el diálogo
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        // Cerrar diálogo y regresar al Dashboard
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Limpiar todo el formulario
        setState(() {
          _litrosTanqueController.clear();
          _litrosReservaController.clear();
          _fotoTanque = null;
          _fotoBidones = null;
          _plantaSeleccionada = null;
          _enviando = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reporte enviado correctamente")),
      );
    } catch (e) {
      setState(() => _enviando = false);
      debugPrint("Error al enviar reporte: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar reporte: $e')),
      );
    }
  }

  // --- Verifica si todos los campos y fotos están completos
  bool get _formularioCompleto =>
      _plantaSeleccionada != null &&
      _litrosTanqueController.text.isNotEmpty &&
      _litrosReservaController.text.isNotEmpty &&
      _fotoTanque != null &&
      _fotoBidones != null;

  // --- UI principal
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporte de Combustible"),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de planta
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Selecciona la planta',
                border: OutlineInputBorder(),
              ),
              initialValue: _plantaSeleccionada,
              items: _plantas
                  .map((planta) => DropdownMenuItem(
                        value: planta,
                        child: Text(planta),
                      ))
                  .toList(),
              onChanged: (valor) {
                setState(() {
                  _plantaSeleccionada = valor;
                });
              },
            ),
            const SizedBox(height: 16),

            // Campo litros tanque
            TextField(
              controller: _litrosTanqueController,
              decoration: const InputDecoration(
                labelText: 'Litros en tanque (aproximado)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Campo litros reserva
            TextField(
              controller: _litrosReservaController,
              decoration: const InputDecoration(
                labelText: 'Litros de reserva',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Fotos requeridas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildImageBox(
                  "Foto del tanque",
                  _fotoTanque,
                  () => _tomarFoto(true),
                ),
                _buildImageBox(
                  "Foto de bidones",
                  _fotoBidones,
                  () => _tomarFoto(false),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Botón enviar
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _formularioCompleto ? Colors.indigo : Colors.grey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed:
                    _formularioCompleto && !_enviando ? _enviarReporte : null,
                label: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Enviar reporte"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget reutilizable para mostrar imagen o botón de cámara
  Widget _buildImageBox(String titulo, File? imagen, VoidCallback onPressed) {
    return Column(
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.indigo),
              borderRadius: BorderRadius.circular(10),
            ),
            child: imagen != null
                ? Image.file(imagen, fit: BoxFit.cover)
                : const Icon(Icons.camera_alt, size: 40, color: Colors.indigo),
          ),
        ),
      ],
    );
  }
}

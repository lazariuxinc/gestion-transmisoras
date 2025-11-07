// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class ReporteCombustibleTab extends StatefulWidget {
  const ReporteCombustibleTab({super.key});

  @override
  State<ReporteCombustibleTab> createState() => _ReporteCombustibleTabState();
}

class _ReporteCombustibleTabState extends State<ReporteCombustibleTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _litrosTanque = TextEditingController();
  final TextEditingController _litrosReserva = TextEditingController();
  final picker = ImagePicker();

  File? _fotoTanque;
  File? _fotoReserva;
  String? _plantaSeleccionada;
  bool _enviando = false;

  final List<String> _plantas = [
    'Periférico',
    'La Venta',
    'Boca del Cerro',
    'Cunduacán'
  ];

  final player = AudioPlayer();

  /// Toma una foto desde la cámara y la guarda en la variable correspondiente
  Future<void> _tomarFoto(bool esTanque) async {
    final XFile? imagen =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (imagen != null) {
      setState(() {
        if (esTanque) {
          _fotoTanque = File(imagen.path);
        } else {
          _fotoReserva = File(imagen.path);
        }
      });
    }
  }

  /// Sube las fotos a Firebase Storage y devuelve las URLs públicas
  Future<Map<String, String>> _subirFotos(String planta, String fechaId) async {
    final storage = FirebaseStorage.instance;
    final carpeta = 'reportes_combustible/$planta/$fechaId';
    String? urlTanque;
    String? urlReserva;

    if (_fotoTanque != null) {
      final refTanque = storage.ref('$carpeta/foto_tanque.jpg');
      await refTanque.putFile(_fotoTanque!);
      urlTanque = await refTanque.getDownloadURL();
    }

    if (_fotoReserva != null) {
      final refReserva = storage.ref('$carpeta/foto_reserva.jpg');
      await refReserva.putFile(_fotoReserva!);
      urlReserva = await refReserva.getDownloadURL();
    }

    return {
      'fotoTanque': urlTanque ?? '',
      'fotoReserva': urlReserva ?? '',
    };
  }

  /// Envía el reporte a Firestore con validaciones completas
  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fotoTanque == null || _fotoReserva == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes tomar ambas fotos antes de enviar el reporte."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    final now = DateTime.now();
    final fechaId = DateFormat('yyyyMMdd_HHmmss').format(now);

    try {
      final urls = await _subirFotos(_plantaSeleccionada!, fechaId);

      await FirebaseFirestore.instance.collection('reportes_combustible').add({
        'planta': _plantaSeleccionada,
        'litrosTanque': _litrosTanque.text.trim(),
        'litrosReserva': _litrosReserva.text.trim(),
        'fotoTanque': urls['fotoTanque'],
        'fotoReserva': urls['fotoReserva'],
        'fecha': now,
      });

      await player.play(AssetSource('audio/success.mp3'));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/animations/successfully.json',
                      repeat: false),
                  const SizedBox(height: 12),
                  const Text(
                    "Reporte enviado correctamente",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        );

        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        Navigator.of(context).pop(); // Cierra el diálogo
        Navigator.of(context).pop(); // Regresa al Dashboard
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al enviar el reporte: $e")),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _plantaSeleccionada,
                  items: _plantas
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: "Seleccionar planta",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _plantaSeleccionada = val),
                  validator: (v) => v == null ? 'Selecciona una planta' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _litrosTanque,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Litros en tanque",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _litrosReserva,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Litros de reserva",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _fotoTanque == null
                        ? OutlinedButton.icon(
                            onPressed: () => _tomarFoto(true),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Foto tanque"),
                          )
                        : Image.file(_fotoTanque!,
                            width: 100, height: 100, fit: BoxFit.cover),
                    _fotoReserva == null
                        ? OutlinedButton.icon(
                            onPressed: () => _tomarFoto(false),
                            icon: const Icon(Icons.camera),
                            label: const Text("Foto reserva"),
                          )
                        : Image.file(_fotoReserva!,
                            width: 100, height: 100, fit: BoxFit.cover),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _enviando ? null : _enviarReporte,
                  icon: const Icon(Icons.send),
                  label: Text(_enviando ? "Enviando..." : "Enviar reporte"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// lib/pages/combustible_page.dart
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';

// ▼▼▼ CAMBIO ▼▼▼
// Ya no necesitamos importar el 'fuel_level_selector.dart'
// import '../widgets/fuel_level_selector.dart';

class CombustiblePage extends StatefulWidget {
  const CombustiblePage({super.key});

  @override
  State<CombustiblePage> createState() => _CombustiblePageState();
}

class _CombustiblePageState extends State<CombustiblePage> {
  final _litrosReservaCtrl = TextEditingController();

  // Esta variable ahora será controlada por el Slider
  double _nivelTanqueSeleccionado = 0.0;

  String? _plantaSeleccionada;
  File? _fotoTanque;
  File? _fotoReserva;
  bool _enviando = false;

  final List<String> plantas = [
    'Periférico',
    'La Venta',
    'Boca del Cerro',
    'Cunduacán'
  ];

  // La validación sigue funcionando igual.
  // _nivelTanqueSeleccionado > 0.0 comprueba que el slider no esté en "Vacío".
  bool get _puedeEnviar =>
      _plantaSeleccionada != null &&
      _fotoTanque != null &&
      _fotoReserva != null &&
      _nivelTanqueSeleccionado > 0.0 &&
      _litrosReservaCtrl.text.isNotEmpty;

  Future<void> _tomarFoto(bool esTanque) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image != null) {
      setState(() {
        if (esTanque) {
          _fotoTanque = File(image.path);
        } else {
          _fotoReserva = File(image.path);
        }
      });
    }
  }

  Future<void> _enviarReporte() async {
    if (!_puedeEnviar) return;

    setState(() => _enviando = true);

    try {
      final timestamp = DateTime.now().toIso8601String();
      final storage = FirebaseStorage.instance;

      final refTanque = storage
          .ref()
          .child('reportes/$_plantaSeleccionada/tanque_$timestamp.jpg');
      final refReserva = storage
          .ref()
          .child('reportes/$_plantaSeleccionada/reserva_$timestamp.jpg');

      await refTanque.putFile(_fotoTanque!);
      await refReserva.putFile(_fotoReserva!);

      final urlTanque = await refTanque.getDownloadURL();
      final urlReserva = await refReserva.getDownloadURL();

      await FirebaseFirestore.instance.collection('reportes_combustible').add({
        'planta': _plantaSeleccionada,
        'nivel_tanque_aprox':
            _nivelTanqueSeleccionado, // Se guarda el valor del slider (0.0 a 1.0)
        'litros_reserva': _litrosReservaCtrl.text,
        'foto_tanque': urlTanque,
        'foto_reserva': urlReserva,
        'fecha': timestamp,
      });

      final player = AudioPlayer();
      await player.play(AssetSource('audio/success.mp3'));

      if (!mounted) return; // Verificación de seguridad

      // 1. Muestra el diálogo (sin await)
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
                Lottie.asset(
                  'assets/animations/successfully.json',
                  repeat: false,
                  width: 150,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Reporte enviado correctamente",
                  textAlign: TextAlign.center,
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

      // 2. Espera 3 segundos
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return; // Verificación de seguridad

      // 3. Cierra el diálogo
      Navigator.of(context).pop();

      // 4. Navega al Dashboard
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/dashboard', (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de Combustible')),

      // SafeArea para evitar que los botones de navegación tapen la UI
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Selecciona la planta'),
                initialValue: _plantaSeleccionada,
                items: plantas
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _plantaSeleccionada = val),
              ),
              const SizedBox(height: 20),

              // ▼▼▼ CAMBIO PRINCIPAL: DE LISTA A SLIDER ▼▼▼
              const Text('Nivel del Tanque (desliza)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Slider(
                value: _nivelTanqueSeleccionado,
                min: 0.0, // 0%
                max: 1.0, // 100%
                divisions: 8, // Esto crea 9 marcas (0/8, 1/8, 2/8... 8/8)

                // Muestra la etiqueta "x/8" mientras se desliza
                label: '${(_nivelTanqueSeleccionado * 8).round()}/8',

                onChanged: (double newValue) {
                  setState(() {
                    _nivelTanqueSeleccionado = newValue;
                  });
                },
              ),
              // Mostramos el valor seleccionado para confirmación visual
              Center(
                child: Text(
                  'Seleccionado: ${(_nivelTanqueSeleccionado * 8).round()}/8',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700]),
                ),
              ),
              const SizedBox(height: 20),
              // ▲▲▲ FIN DEL CAMBIO ▲▲▲

              TextField(
                controller: _litrosReservaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Litros de reserva (bidones)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              _fotoWidget('Foto del nivel del tanque', true, _fotoTanque),
              const SizedBox(height: 10),
              _fotoWidget(
                  'Foto de los bidones de reserva', false, _fotoReserva),
              const SizedBox(height: 30),

              Center(
                child: ElevatedButton.icon(
                  icon: _enviando
                      ? Container(
                          width: 20,
                          height: 20,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_enviando ? 'Enviando...' : 'Enviar reporte'),
                  // La lógica de validación _puedeEnviar sigue funcionando
                  onPressed: _puedeEnviar && !_enviando ? _enviarReporte : null,
                ),
              ),
              const SizedBox(height: 20), // Espacio extra al final
            ],
          ),
        ),
      ),
    );
  }

  Widget _fotoWidget(String label, bool esTanque, File? foto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _tomarFoto(esTanque),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade100,
            ),
            child: foto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(foto, fit: BoxFit.cover))
                : const Center(child: Icon(Icons.camera_alt, size: 40)),
          ),
        ),
      ],
    );
  }
}

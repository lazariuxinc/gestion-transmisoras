// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'reporte_exitoso_page.dart';

/// Formulario para registrar combustible y horas de planta por estación.
/// - Permite seleccionar planta.
/// - Captura litros en tanque (aprox) + litros de reserva.
/// - Sube foto del tanque (para trazabilidad).
/// - Registra hora inicio / fin (calcula total_horas con seguridad).
/// - Guarda en Firestore y la imagen en Storage.
/// - Redirige a pantalla de éxito (animación + sonido).
class ReporteCombustibleForm extends StatefulWidget {
  /// Nombre visible del usuario autenticado (ej. "Alejandro")
  final String usuario;

  /// Rol del usuario: "superusuario" | "administrador" | "operador"
  final String rol;

  const ReporteCombustibleForm({
    super.key,
    required this.usuario,
    required this.rol,
  });

  @override
  State<ReporteCombustibleForm> createState() => _ReporteCombustibleFormState();
}

class _ReporteCombustibleFormState extends State<ReporteCombustibleForm> {
  final _formKey = GlobalKey<FormState>();

  // --- Campos del formulario ---
  final List<String> _plantas = const [
    'La Venta',
    'Periférico',
    'Boca del Cerro',
    'Cunduacán',
    'Rancho Grande', // sin planta de emergencia, pero sí reportes/solicitudes
  ];

  String? _planta;
  final _litrosTanqueCtrl = TextEditingController(); // aproximado
  final _litrosReservaCtrl = TextEditingController(); // almacenamiento
  final _mantenimientoCtrl = TextEditingController(); // texto libre opcional

  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;

  File? _fotoTanque;
  bool _enviando = false;

  // --- Helpers ---

  /// Seleccionar imagen desde cámara o galería (por ahora cámara).
  Future<void> _tomarFotoTanque() async {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xfile != null) {
      setState(() => _fotoTanque = File(xfile.path));
    }
  }

  Future<void> _seleccionarHoraInicio() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) setState(() => _horaInicio = picked);
  }

  Future<void> _seleccionarHoraFin() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) setState(() => _horaFin = picked);
  }

  /// Convierte TimeOfDay a DateTime "anclado" al día de hoy.
  DateTime _toToday(TimeOfDay t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }

  /// Calcula horas trabajadas de forma segura (acepta cambio de día).
  double _calcularHorasTrabajadas(TimeOfDay inicio, TimeOfDay fin) {
    var a = _toToday(inicio);
    var b = _toToday(fin);
    if (b.isBefore(a)) {
      // Si el fin es "antes", asumimos que cruzó la medianoche.
      b = b.add(const Duration(days: 1));
    }
    final diff = b.difference(a);
    return diff.inMinutes / 60.0;
  }

  /// Valida que el rol pueda enviar (en esta fase, todos los roles pueden).
  bool _puedeEnviar() {
    // Superusuario siempre puede; administradores y operadores también.
    return widget.rol == 'superusuario' ||
        widget.rol == 'administrador' ||
        widget.rol == 'operador';
  }

  /// Subida de archivo a Storage con ruta ordenada: reportes/{planta}/YYYY/MM/dd/{ts}.jpg
  Future<String?> _subirFotoSiExiste(String planta) async {
    if (_fotoTanque == null) return null;
    final now = DateTime.now();
    final path =
        'reportes/${planta.replaceAll(" ", "_")}/${now.year}/${now.month.toString().padLeft(2, "0")}/${now.day.toString().padLeft(2, "0")}/${now.millisecondsSinceEpoch}.jpg';

    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(_fotoTanque!);
    return await ref.getDownloadURL();
  }

  Future<void> _enviar() async {
    if (!_puedeEnviar()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para enviar este reporte.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_horaInicio == null || _horaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona hora de inicio y fin.')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final ahora = DateTime.now();
      final planta = _planta!.trim();

      // 1) Subir imagen (si la hay)
      final fotoUrl = await _subirFotoSiExiste(planta);

      // 2) Calcular horas
      final totalHoras = _calcularHorasTrabajadas(_horaInicio!, _horaFin!);

      // 3) Guardar documento
      await FirebaseFirestore.instance.collection('reportes_combustible').add({
        'planta': planta,
        'operador':
            widget.usuario, // en esta fase, admins también pueden operar
        'rol_operador': widget.rol,
        'fecha': Timestamp.fromDate(ahora),
        'timestamp': ahora.millisecondsSinceEpoch,

        'litros_tanque_aprox': int.parse(_litrosTanqueCtrl.text),
        'litros_reserva': int.parse(_litrosReservaCtrl.text),
        'imagen_tanque_url': fotoUrl,

        'hora_inicio': _toToday(_horaInicio!).toIso8601String(),
        'hora_fin': _toToday(_horaFin!).toIso8601String(),
        'total_horas': double.parse(totalHoras.toStringAsFixed(2)),

        'mantenimiento': _mantenimientoCtrl.text.trim(),
        'nota_aproximado': true, // para mostrar “aproximado” en dashboard
      });

      // 4) Limpiar y navegar a pantalla de éxito
      _formKey.currentState!.reset();
      setState(() {
        _planta = null;
        _fotoTanque = null;
        _horaInicio = null;
        _horaFin = null;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReporteExitosoPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    _litrosTanqueCtrl.dispose();
    _litrosReservaCtrl.dispose();
    _mantenimientoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _enviando;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Combustible'),
        backgroundColor: Colors.green[700],
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Usuario/rol visibles (contexto)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.usuario} • ${widget.rol}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 12),

                // Planta
                DropdownButtonFormField<String>(
                  initialValue: _planta,
                  items: _plantas
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Selecciona la planta',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.factory),
                  ),
                  onChanged: (v) => setState(() => _planta = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Selecciona una planta' : null,
                ),
                const SizedBox(height: 16),

                // Litros tanque (aprox)
                TextFormField(
                  controller: _litrosTanqueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Litros en tanque (aprox.)',
                    helperText:
                        'Se calculará visualmente a partir de la foto (dato aproximado).',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_gas_station),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa litros';
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Litros reserva
                TextFormField(
                  controller: _litrosReservaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Litros en reserva',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Ingresa litros de reserva';
                    }
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Foto tanque
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Tomar foto del tanque'),
                        onPressed: _tomarFotoTanque,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_fotoTanque != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_fotoTanque!,
                        height: 180, fit: BoxFit.cover),
                  ),
                if (_fotoTanque == null)
                  const Text('Sin foto todavía',
                      style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),

                // Horas de planta
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.timer_outlined),
                        label: Text(_horaInicio == null
                            ? 'Hora inicio'
                            : 'Inicio: ${_horaInicio!.format(context)}'),
                        onPressed: _seleccionarHoraInicio,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.timer),
                        label: Text(_horaFin == null
                            ? 'Hora fin'
                            : 'Fin: ${_horaFin!.format(context)}'),
                        onPressed: _seleccionarHoraFin,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mantenimiento (opcional)
                TextFormField(
                  controller: _mantenimientoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mantenimiento (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.build_circle_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Botón Enviar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _enviar,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(isLoading ? 'Enviando...' : 'Enviar reporte'),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Nota: el valor en tanque es un aproximado basado en la imagen.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

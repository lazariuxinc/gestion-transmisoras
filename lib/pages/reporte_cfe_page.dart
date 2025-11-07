// lib/pages/reporte_cfe_page.dart
// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Para copiar al portapapeles

class ReporteCFEPage extends StatefulWidget {
  final String faultId; // Recibe el ID del documento de la falla

  const ReporteCFEPage({super.key, required this.faultId});

  @override
  State<ReporteCFEPage> createState() => _ReporteCFEPageState();
}

class _ReporteCFEPageState extends State<ReporteCFEPage> {
  final TextEditingController _reporteController = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  // Datos a mostrar
  String _estacionNombre = "Cargando...";
  String _numeroServicioCFE = "Cargando...";
  String _nombreTitularCFE = "Cargando...";
  String _direccionEstacion = "Cargando...";
  String _numeroReporteActual = ""; // Para precargar el campo si ya existe

  @override
  void initState() {
    super.initState();
    _cargarDatosFallaYEstacion();
  }

  @override
  void dispose() {
    _reporteController.dispose();
    super.dispose();
  }

  /// Carga los datos de la falla activa y la información CFE de la estación.
  Future<void> _cargarDatosFallaYEstacion() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      // 1. Obtener datos de la falla usando el ID recibido
      DocumentSnapshot fallaDoc = await FirebaseFirestore.instance
          .collection('fallas_electricas')
          .doc(widget.faultId)
          .get();

      if (!fallaDoc.exists) {
        throw Exception("No se encontró el registro de la falla.");
      }

      final fallaData = fallaDoc.data() as Map<String, dynamic>? ?? {};
      _estacionNombre = fallaData['estacion'] ?? "Estación desconocida";
      _numeroReporteActual = fallaData['numeroReporteCFE'] ?? "";
      _reporteController.text = _numeroReporteActual; // Precargar el campo

      // 2. Obtener datos de la estación CFE
      String estacionDocId = _getEstacionDocId(_estacionNombre);
      if (estacionDocId.isNotEmpty) {
        DocumentSnapshot estacionData = await FirebaseFirestore.instance
            .collection('estaciones')
            .doc(estacionDocId)
            .get();

        if (estacionData.exists) {
          _numeroServicioCFE =
              estacionData.get('numeroServicioCFE') ?? "No disponible";
          _nombreTitularCFE =
              estacionData.get('nombreTitularCFE') ?? "No disponible";
          _direccionEstacion = estacionData.get('direccion') ?? "No disponible";
        } else {
          throw Exception(
              "No se encontraron datos para la estación $_estacionNombre");
        }
      } else {
        throw Exception("Nombre de estación no reconocido: $_estacionNombre");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        // Dejar los valores como "Error..."
        _estacionNombre = "Error";
        _numeroServicioCFE = "Error";
        _nombreTitularCFE = "Error";
        _direccionEstacion = "Error";
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Guarda el número de reporte CFE en el documento de la falla.
  Future<void> _guardarReporteYSalir() async {
    if (_guardando) return;
    if (mounted) setState(() => _guardando = true);

    final numeroReporte = _reporteController.text.trim();

    try {
      await FirebaseFirestore.instance
          .collection('fallas_electricas')
          .doc(widget.faultId)
          .update({
        'numeroReporteCFE': numeroReporte.isNotEmpty ? numeroReporte : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Número de reporte guardado.'),
              backgroundColor: Colors.green),
        );
        // Navegar al Dashboard después de guardar
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar reporte: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      // Asegurarse de quitar el indicador si aún está montado
      if (mounted) setState(() => _guardando = false);
    }
  }

  // Helper para obtener el ID corto del documento de estación (debe ser igual al de falla_electrica_page)
  String _getEstacionDocId(String nombreEstacion) {
    final lowerName = nombreEstacion.toLowerCase();
    if (lowerName.contains("boca")) return "boca_del_cerro";
    if (lowerName.contains("cunduacan")) return "cunduacan";
    if (lowerName.contains("periferico")) return "periferico_vh";
    if (lowerName.contains("rancho")) return "rancho_grande";
    if (lowerName.contains("venta")) return "la_venta";
    print(
        "WARN: Nombre de estación no reconocido en _getEstacionDocId: $nombreEstacion"); // Log warning
    return ''; // Devuelve vacío si no coincide
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información Reporte CFE'),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Estación: $_estacionNombre',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 1,
                      color:
                          Colors.blueGrey[50], // Un fondo ligeramente diferente
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos para reportar a CFE:',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 20),
                            _infoCFE('No. Servicio:', _numeroServicioCFE),
                            _infoCFE('Titular:', _nombreTitularCFE),
                            _infoCFE('Dirección:', _direccionEstacion),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton.icon(
                                onPressed: _cargando ||
                                        _numeroServicioCFE.startsWith("No") ||
                                        _numeroServicioCFE.startsWith("Error")
                                    ? null // Deshabilitar si no hay número válido
                                    : () {
                                        Clipboard.setData(ClipboardData(
                                            text: _numeroServicioCFE));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Número de Servicio copiado')),
                                        );
                                      },
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copiar No. Servicio'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _reporteController,
                      keyboardType:
                          TextInputType.text, // Puede incluir letras y números
                      decoration: const InputDecoration(
                        labelText: 'Número de Reporte CFE',
                        hintText: 'Ingresa el número proporcionado por CFE',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                      enabled: !_guardando, // Deshabilitar mientras guarda
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: _guardando
                          ? Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.save_alt_outlined),
                      label: Text(_guardando
                          ? 'Guardando...'
                          : 'Guardar Reporte y Salir'),
                      onPressed: _guardando ? null : _guardarReporteYSalir,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Helper para mostrar la info de CFE (igual que en falla_electrica_page)
  Widget _infoCFE(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 4.0), // Aumentar un poco el espacio
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge ??
              const TextStyle(
                  color: Colors.black87, fontSize: 16), // Un poco más grande
          children: [
            TextSpan(
                text: label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: ' $value'),
          ],
        ),
      ),
    );
  }
}

// lib/pages/falla_electrica_page.dart
// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'dart:async'; // Para el posible Timer si fuera necesario
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Para copiar al portapapeles
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
// TODO: Importar geolocator si se necesita

// Tipos de falla
enum TipoFallaElectrica { variacion, corteTotal }

class FallaElectricaPage extends StatefulWidget {
  const FallaElectricaPage({super.key});

  @override
  State<FallaElectricaPage> createState() => _FallaElectricaPageState();
}

class _FallaElectricaPageState extends State<FallaElectricaPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _notasController = TextEditingController();
  final TextEditingController _reporteCFEController = TextEditingController();

  // --- Estado General ---
  bool _cargando = true;
  String _estacionAsignada = "Desconocida";
  String _userRole = "operador"; // TODO: Leer rol real (claims o Firestore)

  // --- Estado Falla CFE ---
  bool _hayFallaActiva = false;
  DocumentSnapshot? _fallaActivaSnapshot;

  // --- Estado Ciclo Planta ---
  bool _cicloPlantaActivo = false;
  DocumentSnapshot? _cicloPlantaActualSnapshot;

  // --- Datos Estación (para reporte CFE) ---
  String _numeroServicioCFE = "No disponible";
  String _nombreTitularCFE = "No disponible";
  String _direccionEstacion = "No disponible";

  // --- Selección para Nueva Falla ---
  TipoFallaElectrica? _tipoFallaSeleccionada;
  bool _arrancoPlantaInicialmente = false;

  // --- Formateadores ---
  final formatoFechaHora = DateFormat('dd/MM/yyyy HH:mm', 'es');

  @override
  void initState() {
    super.initState();
    _obtenerEstadoInicialYDatosEstacion();
  }

  @override
  void dispose() {
    _notasController.dispose();
    _reporteCFEController.dispose();
    super.dispose();
  }

  // --- LÓGICA PRINCIPAL ---
  Future<void> _obtenerEstadoInicialYDatosEstacion() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    if (currentUser == null) {
      // TODO: Manejar usuario no logueado
      if (mounted) {
        setState(() => _cargando = false);
      }
      return;
    }

    try {
      // 1. Obtener estación y rol del usuario
      // TODO: Implementar lectura real de 'estacionAsignada' y 'rol'
      _estacionAsignada = "Boca del Cerro"; // Temporal

      if (_estacionAsignada != "Desconocida") {
        // 2. Obtener datos de la estación (Número CFE, Titular, Dirección)
        DocumentSnapshot estacionData = await FirebaseFirestore.instance
            .collection('estaciones')
            .doc(_getEstacionDocId(_estacionAsignada))
            .get();

        if (estacionData.exists) {
          _numeroServicioCFE =
              estacionData.get('numeroServicioCFE') ?? "No disponible";
          _nombreTitularCFE =
              estacionData.get('nombreTitularCFE') ?? "No disponible";
          _direccionEstacion = estacionData.get('direccion') ?? "No disponible";
        }

        // 3. Buscar falla activa para esta estación
        QuerySnapshot fallaQuery = await FirebaseFirestore.instance
            .collection('fallas_electricas')
            .where('estacion', isEqualTo: _estacionAsignada)
            .where('estado', isEqualTo: 'activa')
            .limit(1)
            .get();

        if (fallaQuery.docs.isNotEmpty) {
          _hayFallaActiva = true;
          _fallaActivaSnapshot = fallaQuery.docs.first;
          _reporteCFEController.text =
              _fallaActivaSnapshot!.get('numeroReporteCFE') ?? '';

          QuerySnapshot cicloQuery = await _fallaActivaSnapshot!.reference
              .collection('ciclos_planta')
              .orderBy('timestampInicioPlanta', descending: true)
              .limit(1)
              .get();

          if (cicloQuery.docs.isNotEmpty) {
            _cicloPlantaActualSnapshot = cicloQuery.docs.first;
            _cicloPlantaActivo =
                _cicloPlantaActualSnapshot!.get('estadoCiclo') == 'activo';
          } else {
            _cicloPlantaActivo = false;
            _cicloPlantaActualSnapshot = null;
          }

          if (_fallaActivaSnapshot!.get('tipoFalla') == 'corte_total') {
            await _obtenerDatosCFE();
          }
        } else {
          _hayFallaActiva = false;
          _fallaActivaSnapshot = null;
          _cicloPlantaActivo = false;
          _cicloPlantaActualSnapshot = null;
          _reporteCFEController.clear();
          if (_tipoFallaSeleccionada == TipoFallaElectrica.corteTotal) {
            await _obtenerDatosCFE();
          }
        }
      }
    } catch (e) {
      // print("Error obteniendo estado inicial: $e"); // Comentado
      _mostrarError('Error al cargar datos: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _obtenerDatosCFE() async {
    try {
      DocumentSnapshot estacionData = await FirebaseFirestore.instance
          .collection('estaciones')
          .doc(_getEstacionDocId(_estacionAsignada))
          .get();
      if (estacionData.exists) {
        _numeroServicioCFE =
            estacionData.get('numeroServicioCFE') ?? "No disponible";
        _nombreTitularCFE =
            estacionData.get('nombreTitularCFE') ?? "No disponible";
        _direccionEstacion = estacionData.get('direccion') ?? "No disponible";
      } else {
        _numeroServicioCFE = "Estación no encontrada";
        _nombreTitularCFE = "-";
        _direccionEstacion = "-";
      }
    } catch (e) {
      // print("Error obteniendo datos CFE: $e"); // Comentado
      _numeroServicioCFE = "Error al leer";
      _nombreTitularCFE = "-";
      _direccionEstacion = "-";
    }
  }

  // Helper para obtener el ID corto del documento de estación
  String _getEstacionDocId(String nombreEstacion) {
    // TODO: Crear una lógica más robusta
    if (nombreEstacion.toLowerCase().contains("boca")) return "boca_del_cerro";
    if (nombreEstacion.toLowerCase().contains("cunduacan")) return "cunduacan";
    if (nombreEstacion.toLowerCase().contains("periferico"))
      return "periferico_vh";
    if (nombreEstacion.toLowerCase().contains("rancho")) return "rancho_grande";
    if (nombreEstacion.toLowerCase().contains("venta")) return "la_venta";
    return nombreEstacion.toLowerCase().replaceAll(" ", "_");
  }

  // --- ACCIONES ---
  Future<void> _registrarInicioFalla() async {
    if (_cargando || currentUser == null || _tipoFallaSeleccionada == null) {
      return;
    }
    if (mounted) {
      setState(() => _cargando = true);
    }

    String tipoFallaStr = _tipoFallaSeleccionada == TipoFallaElectrica.variacion
        ? 'variacion'
        : 'corte_total';
    final nowTimestamp = FieldValue.serverTimestamp();
    final notas = _notasController.text.trim();

    try {
      DocumentReference newFaultRef =
          await FirebaseFirestore.instance.collection('fallas_electricas').add({
        'userId': currentUser!.uid,
        'nombreUsuario':
            currentUser!.displayName ?? currentUser!.email ?? 'N/A',
        'estacion': _estacionAsignada,
        'tipoFalla': tipoFallaStr,
        'timestampInicio': nowTimestamp,
        'timestampFin': null,
        'duracionMinutos': null,
        'numeroReporteCFE': null,
        'notasInicio': notas.isNotEmpty ? notas : null,
        'notasFin': null,
        'estado': 'activa',
      });

      if (_arrancoPlantaInicialmente) {
        await newFaultRef.collection('ciclos_planta').add({
          'timestampInicioPlanta': nowTimestamp,
          'timestampFinPlanta': null,
          'duracionCicloMinutos': null,
          'userIdInicio': currentUser!.uid,
          'userIdFin': null,
          'estadoCiclo': 'activo',
        });
      }

      // TODO: Disparar notificación Cloud Function
      await _mostrarDialogoExito("Inicio de falla registrado",
          navigateToDashboard: tipoFallaStr != 'corte_total',
          faultIdForCFEPage:
              tipoFallaStr == 'corte_total' ? newFaultRef.id : null);
    } catch (e) {
      _mostrarError('Error al registrar inicio: ${e.toString()}');
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _registrarEncendidoPlanta() async {
    if (_cargando ||
        currentUser == null ||
        !_hayFallaActiva ||
        _fallaActivaSnapshot == null) {
      return;
    }
    if (mounted) {
      setState(() => _cargando = true);
    }

    try {
      await _fallaActivaSnapshot!.reference.collection('ciclos_planta').add({
        'timestampInicioPlanta': FieldValue.serverTimestamp(),
        'timestampFinPlanta': null,
        'duracionCicloMinutos': null,
        'userIdInicio': currentUser!.uid,
        'userIdFin': null,
        'estadoCiclo': 'activo',
      });

      await _mostrarDialogoExito("Encendido de planta registrado",
          refreshState: true);
    } catch (e) {
      _mostrarError('Error al registrar encendido: ${e.toString()}');
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _registrarApagadoPlanta() async {
    if (_cargando ||
        currentUser == null ||
        !_cicloPlantaActivo ||
        _cicloPlantaActualSnapshot == null) {
      return;
    }
    if (mounted) {
      setState(() => _cargando = true);
    }

    try {
      DocumentReference cicloRef = _cicloPlantaActualSnapshot!.reference;
      Timestamp? inicioTimestamp =
          _cicloPlantaActualSnapshot!.get('timestampInicioPlanta');
      DateTime? inicioDate = inicioTimestamp?.toDate();
      DateTime finDate = DateTime.now();
      int? duracionMinutos;
      if (inicioDate != null) {
        duracionMinutos = finDate.difference(inicioDate).inMinutes;
      }

      await cicloRef.update({
        'timestampFinPlanta': FieldValue.serverTimestamp(),
        'estadoCiclo': 'finalizado',
        'duracionCicloMinutos': duracionMinutos,
        'userIdFin': currentUser!.uid,
      });

      await _mostrarDialogoExito("Apagado de planta registrado",
          refreshState: true);
    } catch (e) {
      _mostrarError('Error al registrar apagado: ${e.toString()}');
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _registrarFinFalla() async {
    if (_cargando ||
        currentUser == null ||
        !_hayFallaActiva ||
        _fallaActivaSnapshot == null) {
      return;
    }

    if (_cicloPlantaActivo) {
      _mostrarError(
          'Error: La planta de emergencia sigue registrada como ENCENDIDA. ' // String adyacente
          'Por favor, registra primero el APAGADO de la planta.');
      return;
    }

    if (mounted) {
      setState(() => _cargando = true);
    }
    final notas = _notasController.text.trim();

    try {
      DocumentReference fallaRef = _fallaActivaSnapshot!.reference;
      Timestamp? inicioTimestamp = _fallaActivaSnapshot!.get('timestampInicio');
      DateTime? inicioDate = inicioTimestamp?.toDate();
      DateTime finDate = DateTime.now();
      int? duracionMinutos;
      if (inicioDate != null) {
        duracionMinutos = finDate.difference(inicioDate).inMinutes;
      }

      // TODO: (Opcional) Calcular duracionTotalPlantaMinutos

      await fallaRef.update({
        'timestampFin': FieldValue.serverTimestamp(),
        'estado': 'resuelta',
        'notasFin': notas.isNotEmpty ? notas : null,
        'duracionMinutos': duracionMinutos,
      });

      // TODO: Disparar notificación Cloud Function
      await _mostrarDialogoExito("Fin de falla CFE registrado",
          navigateToDashboard: true);
    } catch (e) {
      _mostrarError('Error al registrar fin de falla: ${e.toString()}');
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarNumeroReporte() async {
    if (_cargando || _fallaActivaSnapshot == null) {
      return;
    }
    if (mounted) {
      setState(() => _cargando = true);
    }

    final numeroReporte = _reporteCFEController.text.trim();

    try {
      await _fallaActivaSnapshot!.reference.update({
        'numeroReporteCFE': numeroReporte.isNotEmpty ? numeroReporte : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Número de reporte guardado.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _mostrarError('Error al guardar número de reporte: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  // --- Helpers UI ---
  Future<void> _mostrarDialogoExito(String mensaje,
      {bool navigateToDashboard = false,
      bool refreshState = false,
      String? faultIdForCFEPage}) async {
    final player = AudioPlayer();
    player
        .play(AssetSource('audio/success.mp3'))
        .catchError((e) {/* print("Error audio: $e"); */});

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
    Navigator.of(context).pop(); // Cierra diálogo

    if (faultIdForCFEPage != null) {
      // TODO: Navegar a ReporteCFEPage pasando el ID
      // print("Navegar a ReporteCFEPage con ID: $faultIdForCFEPage"); // Comentado
      Navigator.pushReplacementNamed(context, '/reporte_cfe',
          arguments: faultIdForCFEPage);
    } else if (navigateToDashboard) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/dashboard', (route) => false);
    } else if (refreshState) {
      _obtenerEstadoInicialYDatosEstacion();
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(mensaje),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  // Widget _infoCFE (Corregido para ser const si es posible, aunque aquí no puede por el context)
  Widget _infoCFE(String label, String value) {
    return Padding(
      // SIN const aquí por el context
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Padding requerido
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium ??
              const TextStyle(color: Colors.black), // Estilo por defecto
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

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatoFechaHora = DateFormat('dd/MM/yyyy HH:mm', 'es');

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar Falla Eléctrica')),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        'Usuario: ${currentUser?.displayName ?? currentUser?.email ?? 'N/A'}',
                        style: theme.textTheme.titleMedium),
                    Text('Estación: $_estacionAsignada',
                        style: theme.textTheme.titleMedium),
                    const Divider(height: 30, thickness: 1),
                    if (_hayFallaActiva && _fallaActivaSnapshot != null)
                      _buildVistaFallaActiva(theme, formatoFechaHora)
                    else
                      _buildVistaNuevaFalla(theme),
                  ],
                ),
              ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---
  Widget _buildVistaFallaActiva(ThemeData theme, DateFormat formatoFechaHora) {
    final data = _fallaActivaSnapshot!.data() as Map<String, dynamic>? ?? {};
    final tipoFalla = data['tipoFalla'] ?? 'desconocido';
    final inicioTimestamp = data['timestampInicio'] as Timestamp?;
    final notasInicio = data['notasInicio'] as String?;
    // Variable reporteCFE eliminada

    final cicloData =
        _cicloPlantaActualSnapshot?.data() as Map<String, dynamic>? ?? {};
    final inicioPlantaTimestamp =
        cicloData['timestampInicioPlanta'] as Timestamp?;

    // TODO: Implementar lógica de roles
    bool puedeEditarReporteCFE = (_userRole == 'operador' ||
        _userRole == 'admin' ||
        _userRole == 'superusuario');
    bool puedeOperarPlanta = (_userRole == 'operador');
    bool puedeCerrarFalla = (_userRole == 'operador');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FALLA ACTIVA',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.error, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Text(
            'Tipo: ${tipoFalla == 'variacion' ? 'Variación de Voltaje' : 'Corte Total'}',
            style: theme.textTheme.titleMedium),
        Text(
            'Inicio Falla CFE: ${inicioTimestamp != null ? formatoFechaHora.format(inicioTimestamp.toDate()) : 'N/A'}',
            style: theme.textTheme.titleMedium),
        if (notasInicio != null && notasInicio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: Text('Notas Inicio: $notasInicio',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ),

        // --- SECCIÓN PLANTA DE EMERGENCIA ---
        const Divider(height: 30),
        Text(
          'Planta de Emergencia:',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (_cicloPlantaActivo) ...[
          Text(
            'ESTADO: ENCENDIDA',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.green[700], fontWeight: FontWeight.bold),
          ),
          Text(
            'Desde: ${inicioPlantaTimestamp != null ? formatoFechaHora.format(inicioPlantaTimestamp.toDate()) : 'N/A'}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: puedeOperarPlanta && !_cargando
                ? _registrarApagadoPlanta
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
            child: const Text('Registrar APAGADO de Planta'), // Child al final
          ),
        ] else ...[
          Text(
            'ESTADO: APAGADA',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: Colors.red[700], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: puedeOperarPlanta && !_cargando
                ? _registrarEncendidoPlanta
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child:
                const Text('Registrar ENCENDIDO de Planta'), // Child al final
          ),
        ],

        // --- SECCIÓN REPORTE CFE ---
        if (tipoFalla == 'corte_total') ...[
          const Divider(height: 30),
          Text(
            'Reporte CFE',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          _infoCFE('No. Servicio:', _numeroServicioCFE),
          _infoCFE('Titular:', _nombreTitularCFE),
          _infoCFE('Dirección:', _direccionEstacion),
          const SizedBox(height: 15),
          TextField(
            controller: _reporteCFEController,
            decoration: const InputDecoration(
              labelText: 'Número de Reporte CFE',
              hintText: 'Ingresar número proporcionado por CFE',
              border: OutlineInputBorder(),
            ),
            enabled: puedeEditarReporteCFE && !_cargando,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: puedeEditarReporteCFE && !_cargando
                ? _guardarNumeroReporte
                : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary),
            child: const Text('Guardar No. Reporte'), // Child al final
          ),
        ],

        // --- SECCIÓN FIN DE FALLA CFE ---
        const Divider(height: 30),
        TextField(
          controller: _notasController..text = (data['notasFin'] ?? ''),
          decoration: const InputDecoration(
            labelText: 'Notas Finales (Opcional)',
            hintText: 'Ej: Servicio restablecido, voltaje normal...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          enabled: !_cargando,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: puedeCerrarFalla && !_cargando ? _registrarFinFalla : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
          ),
          icon: const Icon(
              Icons.electrical_services_outlined), // Icon y Label al final
          label: const Text('Registrar FIN de Falla CFE'),
        ),
      ],
    );
  }

  Widget _buildVistaNuevaFalla(ThemeData theme) {
    // TODO: Implementar lógica de roles
    bool puedeRegistrar = (_userRole == 'operador' ||
        _userRole == 'admin' ||
        _userRole == 'superusuario');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Registrar Nueva Falla',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text('Tipo de Falla:', style: theme.textTheme.titleMedium),
        // ignore: deprecated_member_use
        RadioListTile<TipoFallaElectrica>(
          title: const Text('Variación de Voltaje'),
          value: TipoFallaElectrica.variacion,
          // ignore: deprecated_member_use
          groupValue: _tipoFallaSeleccionada,
          // ignore: deprecated_member_use
          onChanged: !_cargando
              ? (value) {
                  if (mounted) {
                    setState(() => _tipoFallaSeleccionada = value);
                  }
                }
              : null,
        ),
        // ignore: deprecated_member_use
        RadioListTile<TipoFallaElectrica>(
          title: const Text('Corte Total de Suministro'),
          value: TipoFallaElectrica.corteTotal,
          // ignore: deprecated_member_use
          groupValue: _tipoFallaSeleccionada,
          // ignore: deprecated_member_use
          onChanged: !_cargando
              ? (value) async {
                  if (mounted) {
                    setState(() => _tipoFallaSeleccionada = value);
                  }
                  if (value == TipoFallaElectrica.corteTotal &&
                      _numeroServicioCFE == "No disponible") {
                    if (mounted) {
                      setState(() => _cargando = true);
                    }
                    await _obtenerDatosCFE();
                    if (mounted) {
                      setState(() => _cargando = false);
                    }
                  }
                }
              : null,
        ),
        const SizedBox(height: 10),

        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState:
              _tipoFallaSeleccionada == TipoFallaElectrica.corteTotal
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
          firstChild: Card(
            color: Colors.amber[50],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Información para reporte CFE:',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  _infoCFE('No. Servicio:', _numeroServicioCFE),
                  _infoCFE('Titular:', _nombreTitularCFE),
                  _infoCFE('Dirección:', _direccionEstacion),
                  Center(
                      child: TextButton.icon(
                    onPressed: !_cargando
                        ? () {
                            Clipboard.setData(
                                ClipboardData(text: _numeroServicioCFE));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Número de Servicio copiado')),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.copy,
                        size: 16), // Mover icon y label al final
                    label: const Text('Copiar No. Servicio'),
                  )),
                ],
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),

        const SizedBox(height: 20),
        // TODO: Añadir if (_userRole == 'operador') aquí
        CheckboxListTile(
          title: const Text('¿Arrancó la Planta de Emergencia inicialmente?'),
          value: _arrancoPlantaInicialmente,
          onChanged: !_cargando
              ? (value) =>
                  setState(() => _arrancoPlantaInicialmente = value ?? false)
              : null,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _notasController,
          decoration: const InputDecoration(
            labelText: 'Notas Iniciales (Opcional)',
            hintText: 'Ej: Voltaje medido 90V...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          enabled: !_cargando,
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed:
              puedeRegistrar && _tipoFallaSeleccionada != null && !_cargando
                  ? _registrarInicioFalla
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
          ),
          icon: _cargando
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(2.0),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Icon(Icons.power_off), // Mover icon y label al final
          label:
              Text(_cargando ? 'Registrando...' : 'Registrar Inicio de Falla'),
        ),
      ],
    );
  }
} // Fin

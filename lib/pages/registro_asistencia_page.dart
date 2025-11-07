// lib/pages/registro_asistencia_page.dart
// ignore_for_file: depend_on_referenced_packages // Ignoramos temporalmente

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el usuario actual
// Necesitaremos 'intl' para formatear fecha/hora
import 'package:intl/intl.dart';
// Necesitaremos 'dart:async' para el Timer del reloj
import 'dart:async';

class RegistroAsistenciaPage extends StatefulWidget {
  const RegistroAsistenciaPage({super.key});

  @override
  State<RegistroAsistenciaPage> createState() => _RegistroAsistenciaPageState();
}

class _RegistroAsistenciaPageState extends State<RegistroAsistenciaPage> {
  // Estado para saber si el turno está activo y cuándo inició
  bool _estaEnTurno = false;
  DateTime? _horaEntrada;
  String _estadoActual = "Verificando estado..."; // Mensaje inicial

  // Para mostrar la hora actual
  late Timer _timer;
  DateTime _horaActual = DateTime.now();

  // Para obtener el usuario actual
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Estado para botones y carga
  bool _puedeRegistrarEntrada = false;
  bool _puedeRegistrarSalida = false;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    // Iniciar el temporizador para actualizar el reloj cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Solo actualizar si el widget sigue en pantalla
        setState(() {
          _horaActual = DateTime.now();
        });
      }
    });
    // TODO: Llamar a una función para obtener el estado inicial desde Firestore
    _obtenerEstadoInicial();
  }

  @override
  void dispose() {
    _timer.cancel(); // Detener el timer al salir de la pantalla
    super.dispose();
  }

  // --- Funciones de Lógica (Placeholders) ---

  Future<void> _obtenerEstadoInicial() async {
    // TODO: Consultar Firestore por el último registro del currentUser.uid
    // TODO: Basado en el último registro ('entrada' o 'salida'), actualizar:
    // setState(() {
    //   _estaEnTurno = ...;
    //   _horaEntrada = ...; // Si aplica
    //   _actualizarEstadoBotones();
    // });
    // Simulación temporal:
    await Future.delayed(const Duration(seconds: 1)); // Simula carga
    if (mounted) {
      setState(() {
        _estaEnTurno = false; // Asumir fuera de turno inicialmente
        _actualizarEstadoBotones();
      });
    }
  }

  Future<void> _registrarEntrada() async {
    if (_cargando) return;
    if (mounted) setState(() => _cargando = true);

    // TODO: 1. Obtener Geolocalización (con geolocator)
    // TODO: 2. Crear documento en Firestore 'registros_asistencia' con tipo 'entrada'
    // TODO: 3. Si es exitoso:
    // TODO:    Mostrar diálogo de éxito con Lottie y texto "Registro de asistencia correcto"
    // TODO:    Esperar 3 segundos
    // TODO:    Cerrar diálogo
    // TODO:    Navegar a '/dashboard'
    // TODO: 4. Si falla, mostrar SnackBar de error
    // TODO: 5. En finally: setState(() => _cargando = false); (dentro de if mounted)

    // Simulación temporal de éxito:
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      // Mostrar diálogo simulado (reemplazar con el real luego)
      showDialog(
          context: context,
          builder: (_) => const AlertDialog(
              title: Text("Éxito"),
              content: Text("Entrada registrada (simulado)")));
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.of(context).pop(); // Cierra diálogo
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _registrarSalida() async {
    if (_cargando) return;
    if (mounted) setState(() => _cargando = true);

    // TODO: 1. Obtener Geolocalización
    // TODO: 2. Crear documento en Firestore 'registros_asistencia' con tipo 'salida'
    // TODO: 3. Si es exitoso:
    // TODO:    Mostrar diálogo de éxito con Lottie y texto "Registro de asistencia correcto"
    // TODO:    Esperar 3 segundos
    // TODO:    Cerrar diálogo
    // TODO:    Navegar a '/dashboard'
    // TODO: 4. Si falla, mostrar SnackBar de error
    // TODO: 5. En finally: setState(() => _cargando = false); (dentro de if mounted)

    // Simulación temporal de éxito:
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      // Mostrar diálogo simulado (reemplazar con el real luego)
      showDialog(
          context: context,
          builder: (_) => const AlertDialog(
              title: Text("Éxito"),
              content: Text("Salida registrada (simulado)")));
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.of(context).pop(); // Cierra diálogo
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _actualizarEstadoBotones() {
    if (_estaEnTurno) {
      _puedeRegistrarEntrada = false;
      _puedeRegistrarSalida = true;
      // Formatear la hora de entrada para mostrarla
      final formatoEntrada = DateFormat('dd/MM/yyyy HH:mm');
      _estadoActual =
          "Turno iniciado el ${formatoEntrada.format(_horaEntrada ?? DateTime.now())}"; // Usar la hora guardada
    } else {
      _puedeRegistrarEntrada = true;
      _puedeRegistrarSalida = false;
      _estadoActual = "Estado: Fuera de turno";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Formateador para el reloj principal
    final formatoReloj = DateFormat('HH:mm:ss');
    final formatoFecha = DateFormat('EEEE, dd MMMM yyyy', 'es'); // Español

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Asistencia'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Centrar contenido verticalmente
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Estirar botones horizontalmente
            children: [
              // Reloj Actual
              Text(
                formatoReloj.format(_horaActual),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              // Fecha Actual
              Text(
                formatoFecha.format(_horaActual),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // Información del Usuario
              if (currentUser != null)
                Text(
                  'Usuario: ${currentUser!.displayName ?? currentUser!.email ?? 'Desconocido'}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              const SizedBox(height: 8),

              // Estación (Por ahora fija)
              Text(
                'Estación: Boca del Cerro', // TODO: Hacer esto dinámico si es necesario
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 30),

              // Estado Actual
              Text(
                _estadoActual,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _estaEnTurno ? Colors.green[700] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 50),

              // Botón de Entrada
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Registrar Entrada'),
                // Habilitar/deshabilitar según estado y si está cargando
                onPressed: _puedeRegistrarEntrada && !_cargando
                    ? _registrarEntrada
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor:
                      Colors.green[700], // Color verde para entrada
                ),
              ),
              const SizedBox(height: 20),

              // Botón de Salida
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Registrar Salida'),
                // Habilitar/deshabilitar según estado y si está cargando
                onPressed: _puedeRegistrarSalida && !_cargando
                    ? _registrarSalida
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor:
                      theme.colorScheme.primary, // Color vino para salida
                ),
              ),

              const SizedBox(height: 30),

              // Indicador de carga (aparece si _cargando es true)
              if (_cargando) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

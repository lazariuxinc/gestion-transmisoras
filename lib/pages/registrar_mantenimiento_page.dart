// lib/pages/registrar_mantenimiento_page.dart
// ignore_for_file: depend_on_referenced_packages // Ignoramos temporalmente

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// TODO: Considerar importar Lottie/Audioplayers si se usarán para éxito

class RegistrarMantenimientoPage extends StatefulWidget {
  const RegistrarMantenimientoPage({super.key});

  @override
  State<RegistrarMantenimientoPage> createState() =>
      _RegistrarMantenimientoPageState();
}

class _RegistrarMantenimientoPageState
    extends State<RegistrarMantenimientoPage> {
  final _formKey = GlobalKey<FormState>(); // Para validaciones
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _descripcionController = TextEditingController();

  // --- Estado del formulario ---
  String?
      _estacionSeleccionada; // ID corto de la estación (ej: 'boca_del_cerro')
  String? _tipoMantenimientoSeleccionado;
  bool _cargando = false; // Para mostrar indicador de progreso
  bool _cargandoEstaciones = true; // Para cargar la lista de estaciones

  // --- Listas para Dropdowns ---
  List<DropdownMenuItem<String>> _listaEstacionesItems = [];
  final List<String> _tiposMantenimiento = const [
    'Preventivo Mayor', // Este reinicia contador
    'Preventivo Menor',
    'Correctivo',
    'Trabajo Menor',
  ];

  @override
  void initState() {
    super.initState();
    _obtenerEstaciones(); // Carga las estaciones al iniciar
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  // --- Lógica ---

  /// Obtiene la lista de estaciones desde Firestore para el Dropdown.
  Future<void> _obtenerEstaciones() async {
    if (mounted) setState(() => _cargandoEstaciones = true);
    try {
      // Leemos todos los documentos de la colección 'estaciones'
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('estaciones').get();

      // Creamos los items para el Dropdown
      final items = snapshot.docs.map((doc) {
        // Usamos el ID del documento como valor y el campo 'nombre' como texto visible
        return DropdownMenuItem<String>(
          value: doc.id, // ej: 'boca_del_cerro'
          child: Text(doc.get('nombre') ??
              doc.id), // Muestra el nombre, o el ID si no hay nombre
        );
      }).toList();

      if (mounted) {
        setState(() {
          _listaEstacionesItems = items;
          _cargandoEstaciones = false;
        });
      }
    } catch (e) {
      print("Error obteniendo estaciones: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar estaciones: $e')),
        );
        setState(
            () => _cargandoEstaciones = false); // Termina la carga aunque falle
      }
    }
  }

  /// Guarda el registro de mantenimiento en Firestore.
  Future<void> _guardarMantenimiento() async {
    // 1. Valida el formulario usando la GlobalKey
    if (!_formKey.currentState!.validate()) {
      return; // Si no es válido, detiene la ejecución
    }
    // Evita múltiples envíos si ya está cargando
    if (_cargando) return;

    // 2. Muestra indicador de carga
    if (mounted) setState(() => _cargando = true);

    try {
      // 3. Obtiene los datos del formulario y del usuario
      final String descripcion = _descripcionController.text.trim();
      final String tipoMantenimiento = _tipoMantenimientoSeleccionado!;
      final String estacionId = _estacionSeleccionada!;
      // Obtenemos el nombre legible de la estación a partir del ID seleccionado
      // (Esta forma es segura si _listaEstacionesItems está actualizada)
      final nombreEstacion = (_listaEstacionesItems
                  .firstWhere((item) => item.value == estacionId)
                  .child as Text) // Casteamos a Text para acceder a 'data'
              .data ??
          estacionId; // Usamos el ID como fallback si el Text es nulo

      final userId = currentUser?.uid ?? 'Desconocido';
      final userName = currentUser?.displayName ?? currentUser?.email ?? 'N/A';
      final nowTimestamp =
          FieldValue.serverTimestamp(); // Usar timestamp del servidor

      // --- Operaciones en Firestore ---

      // 4. Crear documento en la colección 'mantenimientos'
      await FirebaseFirestore.instance.collection('mantenimientos').add({
        'estacion': nombreEstacion,
        'estacionId':
            estacionId, // Guardar ID para referencias futuras si es necesario
        'fecha': nowTimestamp,
        'tipoMantenimiento': tipoMantenimiento,
        'descripcion': descripcion,
        'usuarioRegistro': userId,
        'nombreUsuarioRegistro': userName,
      });

      // 5. Si es Preventivo Mayor, reiniciar contador en 'estaciones'
      if (tipoMantenimiento == 'Preventivo Mayor') {
        await FirebaseFirestore.instance
            .collection('estaciones')
            .doc(estacionId)
            .update({
          'horasAcumuladas': 0, // Reinicia el contador
          'fechaUltimoPreventivoMayor': nowTimestamp, // Actualiza la fecha
        });
        print(
            'Contador de horas reiniciado para $nombreEstacion.'); // Log para depuración
      }

      // 6. Mostrar éxito y regresar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mantenimiento registrado con éxito.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2), // Mostrar por 2 segundos
          ),
        );
        // Espera un poco antes de navegar para que se vea el SnackBar
        await Future.delayed(const Duration(milliseconds: 2100));
        if (mounted) {
          Navigator.of(context)
              .pop(); // Cierra esta pantalla y regresa al Dashboard
        }
      }
    } catch (e) {
      // 7. Manejo de errores
      print("Error guardando mantenimiento: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // 8. Ocultar indicador de carga (siempre, incluso con errores)
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- Interfaz de Usuario ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Mantenimiento'),
      ),
      body: SafeArea(
        child:
            _cargandoEstaciones // Muestra carga si está obteniendo estaciones
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    // Permite scroll si el contenido es largo
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      // Usamos Form para validaciones
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- Selector de Estación ---
                          DropdownButtonFormField<String>(
                            value: _estacionSeleccionada,
                            items: _listaEstacionesItems,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _estacionSeleccionada = value);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Seleccionar Estación',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.factory_outlined),
                            ),
                            // Validación: Asegura que se seleccione una estación
                            validator: (value) => value == null
                                ? 'Selecciona una estación'
                                : null,
                          ),
                          const SizedBox(height: 20.0),

                          // --- Selector de Tipo de Mantenimiento ---
                          DropdownButtonFormField<String>(
                            value: _tipoMantenimientoSeleccionado,
                            items: _tiposMantenimiento.map((String tipo) {
                              return DropdownMenuItem<String>(
                                value: tipo,
                                child: Text(tipo),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() =>
                                    _tipoMantenimientoSeleccionado = value);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Mantenimiento',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.build_outlined),
                            ),
                            // Validación: Asegura que se seleccione un tipo
                            validator: (value) =>
                                value == null ? 'Selecciona el tipo' : null,
                          ),
                          const SizedBox(height: 20.0),

                          // --- Campo de Descripción ---
                          TextFormField(
                            controller: _descripcionController,
                            decoration: const InputDecoration(
                              labelText: 'Descripción del Trabajo Realizado',
                              hintText: 'Ej: Cambio de aceite y filtros...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                            maxLines: 4, // Permite escribir más texto
                            // Validación: Asegura que se ingrese una descripción
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Ingresa una descripción'
                                    : null,
                          ),
                          const SizedBox(height: 30.0),

                          // --- Botón Guardar ---
                          ElevatedButton.icon(
                            icon: _cargando
                                ? Container(
                                    // Indicador de carga pequeño
                                    width: 20,
                                    height: 20,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(Icons.save_alt_outlined),
                            label: Text(_cargando
                                ? 'Guardando...'
                                : 'Guardar Registro'),
                            onPressed: _cargando
                                ? null
                                : _guardarMantenimiento, // Deshabilita si está cargando
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              textStyle: const TextStyle(fontSize: 18),
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

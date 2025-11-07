// lib/pages/admin_usuarios_page.dart
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// (No necesitamos FirebaseAuth aquí, la Cloud Function se encargará de eso)

class AdminUsuariosPage extends StatefulWidget {
  const AdminUsuariosPage({super.key});

  @override
  State<AdminUsuariosPage> createState() => _AdminUsuariosPageState();
}

class _AdminUsuariosPageState extends State<AdminUsuariosPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController(); // Añadido

  // --- Estado del formulario ---
  String? _rolSeleccionado;
  String? _estacionSeleccionadaId; // ej: 'boca_del_cerro'
  bool _cargando = false;
  bool _cargandoEstaciones = true;

  // --- Listas para Dropdowns ---
  List<DropdownMenuItem<String>> _listaEstacionesItems = [];
  final List<String> _roles = const [
    'operador',
    'supervisor',
    'admin',
    'superusuario',
  ];

  @override
  void initState() {
    super.initState();
    _obtenerEstaciones(); // Carga las estaciones al iniciar
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  // --- LÓGICA ---

  /// Obtiene la lista de estaciones desde Firestore para el Dropdown.
  Future<void> _obtenerEstaciones() async {
    if (mounted) setState(() => _cargandoEstaciones = true);
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('estaciones').get();

      final items = snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // ID del documento (ej: 'boca_del_cerro')
          child: Text(doc.get('nombre') ?? doc.id),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _listaEstacionesItems = items;
          _cargandoEstaciones = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al cargar estaciones: ${e.toString()}');
        setState(() => _cargandoEstaciones = false);
      }
    }
  }

  /// Lógica para agregar el usuario (llamará a una Cloud Function)
  Future<void> _agregarUsuario() async {
    // 1. Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return; // Validación fallida
    }
    if (_cargando) return;

    if (mounted) setState(() => _cargando = true);

    // 2. Preparar los datos para enviar a la Cloud Function
    // Las claves (ej: 'identificador') DEBEN coincidir con las que espera la función
    final datosParaFuncion = {
      'identificador':
          _emailController.text.trim(), // CF espera 'identificador'
      'password': _passwordController.text.trim(),
      'nombre': _nombreController.text.trim(),
      'rol': _rolSeleccionado!,
      'estacionAsignada':
          _estacionSeleccionadaId!, // CF espera 'estacionAsignada'
      'telefonoPersonal': _telefonoController.text.trim(),
    };

    try {
      // 3. Obtener la instancia de la Cloud Function y llamarla
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('crearUsuarioConRol');

      // 4. Enviar los datos y esperar la respuesta
      final result = await callable.call(datosParaFuncion);

      // 5. Manejar el éxito
      //final uid = result.data['uid'];
      // print('Usuario creado con UID: $uid'); // Log de depuración

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Usuario agregado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        // Limpiar el formulario
        _formKey.currentState?.reset();
        _nombreController.clear();
        _emailController.clear();
        _passwordController.clear();
        _telefonoController.clear();
        if (mounted) {
          setState(() {
            _rolSeleccionado = null;
            _estacionSeleccionadaId = null;
          });
        }
        // Opcional: navegar atrás
        // if (mounted) Navigator.of(context).pop();
      }
    } on FirebaseFunctionsException catch (e) {
      // 6. Manejar errores específicos de la Cloud Function
      // (Estos son los mensajes que definimos en index.js)
      // print('Error de Cloud Function: ${e.code} - ${e.message}');
      _mostrarError(e.message ?? 'Error al llamar a la función.');
    } catch (e) {
      // 7. Manejar otros errores (red, etc.)
      // print('Error inesperado: $e');
      _mostrarError('Ocurrió un error inesperado: ${e.toString()}');
    } finally {
      // 8. Detener la carga pase lo que pase
      if (mounted) setState(() => _cargando = false);
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

  // --- INTERFAZ DE USUARIO ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Usuarios'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crear Nuevo Usuario',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24.0),

                // --- Selector de Estación ---
                _cargandoEstaciones
                    ? const Center(
                        child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Cargando estaciones...'),
                      ))
                    : DropdownButtonFormField<String>(
                        value: _estacionSeleccionadaId,
                        items: _listaEstacionesItems,
                        onChanged: (value) =>
                            setState(() => _estacionSeleccionadaId = value),
                        decoration: const InputDecoration(
                          labelText: 'Asignar Estación',
                          prefixIcon: Icon(Icons.factory_outlined),
                        ),
                        validator: (value) =>
                            value == null ? 'Selecciona una estación' : null,
                      ),
                const SizedBox(height: 20.0),

                // --- Nombre Completo ---
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 20.0),

                // --- Email (Identificador) ---
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (Identificador Único)',
                    hintText: 'ej: pedro.boca@corat.mx',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un email';
                    }
                    // Validación simple de email
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Ingresa un email válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // --- Teléfono Personal (Nuevo) ---
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono Personal',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ingresa el teléfono'
                      : null,
                ),
                const SizedBox(height: 20.0),

                // --- Contraseña Temporal ---
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña Temporal',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa una contraseña temporal';
                    }
                    if (value.length < 6) {
                      return 'Debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // --- Selector de Rol ---
                DropdownButtonFormField<String>(
                  value: _rolSeleccionado,
                  items: _roles.map((String rol) {
                    return DropdownMenuItem<String>(
                      value: rol,
                      child: Text(rol.toUpperCase()), // Muestra en mayúsculas
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _rolSeleccionado = value),
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar Rol',
                    prefixIcon: Icon(Icons.security_outlined),
                  ),
                  validator: (value) =>
                      value == null ? 'Selecciona un rol' : null,
                ),
                const SizedBox(height: 30.0),

                // --- Botón Agregar Usuario ---
                ElevatedButton.icon(
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
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(_cargando ? 'Agregando...' : 'Agregar Usuario'),
                  onPressed: _cargando ? null : _agregarUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.green[700], // Color verde para "Agregar"
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

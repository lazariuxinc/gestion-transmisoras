// lib/providers/user_profile_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileProvider with ChangeNotifier {
  // Información del usuario que queremos compartir
  String? _uid;
  String? _nombre;
  String? _email;
  String? _rol;
  String? _estacionAsignada; // Solo una por ahora

  bool _isLoading = false;

  // "Getters" públicos para que otras pantallas lean los datos
  String get uid => _uid ?? '';
  String get nombre => _nombre ?? '';
  String get email => _email ?? '';
  String get rol => _rol ?? 'invitado'; // Default a 'invitado' si no hay rol
  String get estacionAsignada => _estacionAsignada ?? 'ninguna';
  bool get isLoading => _isLoading;

  /// Esta es la función clave: se llama después de iniciar sesión
  Future<void> loadUserProfile(User user) async {
    _isLoading = true;
    notifyListeners(); // Notifica a la UI que "estamos cargando"

    try {
      // 1. Obtener el ROL desde los Custom Claims
      // Forzamos la actualización del token para obtener los claims más recientes
      IdTokenResult tokenResult = await user.getIdTokenResult(true);
      _rol = tokenResult.claims?['role'] as String? ?? 'invitado';

      _uid = user.uid;
      _email = user.email;

      // 2. Obtener los DATOS ADICIONALES (estación, nombre) desde Firestore
      if (_rol != 'invitado') {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>? ?? {};
          _nombre = data['nombre'] ?? user.email; // Fallback al email

          // Leemos la estación (asumimos que es un array)
          List<dynamic> estaciones = data['estacionesPermitidas'] ?? [];
          if (estaciones.isNotEmpty) {
            _estacionAsignada = estaciones[0] as String?;
          }
        } else {
          // Si el documento no existe (ej. un usuario antiguo), usamos defaults
          _nombre = user.email;
          _estacionAsignada = 'ninguna';
          if (_rol == 'operador') {
            print(
                "ADVERTENCIA: El usuario ${user.uid} tiene rol 'operador' pero no tiene documento de perfil en Firestore.");
          }
        }
      }
    } catch (e) {
      print("Error cargando perfil de usuario: $e");
      _rol = 'invitado'; // Si falla, lo dejamos como invitado por seguridad
      _nombre = 'Error';
      _estacionAsignada = 'Error';
    } finally {
      _isLoading = false;
      notifyListeners(); // Notifica a la UI que terminamos de cargar
    }
  }

  /// Limpia los datos al cerrar sesión
  void clearUserProfile() {
    _uid = null;
    _nombre = null;
    _email = null;
    _rol = null;
    _estacionAsignada = null;
    notifyListeners();
  }
}

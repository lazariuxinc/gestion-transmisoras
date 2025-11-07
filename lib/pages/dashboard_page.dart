// lib/pages/dashboard_page.dart
// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // <-- CAMBIO: Importar Provider
import '../providers/user_profile_provider.dart'; // <-- CAMBIO: Importar nuestro Provider

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // CAMBIO: Función _logout actualizada para limpiar el provider
  void _logout() async {
    try {
      // Limpia el estado del usuario en el provider
      Provider.of<UserProfileProvider>(context, listen: false)
          .clearUserProfile();

      // Cierra sesión en Firebase
      await FirebaseAuth.instance.signOut();

      // Navega al login
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print("Error al cerrar sesión: $e");
      // Opcional: Mostrar un SnackBar si falla el logout
    }
  }

  @override
  Widget build(BuildContext context) {
    // CAMBIO: Obtener el perfil del usuario desde el Provider
    // Usamos 'watch' (Provider.of) para que la UI se reconstruya si el perfil cambia
    final userProfile = Provider.of<UserProfileProvider>(context);
    final String userRole = userProfile.rol;
    final String userName = userProfile.nombre; // Para el saludo

    // Obtenemos los colores del tema
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- CAMBIO: Construcción de lista de botones dinámica ---
    List<Widget> dashboardCards = [];

    // 1. Botones visibles para TODOS (incluyendo 'supervisor' que solo lee)
    dashboardCards.add(_dashboardCard(
      context: context,
      icon: Icons.local_gas_station,
      iconColor: Colors.orange.shade700,
      title: 'Combustible',
      onTap: () => Navigator.pushNamed(context, '/combustible'),
    ));
    dashboardCards.add(_dashboardCard(
      context: context,
      icon: Icons.schedule, // Icono de reloj
      iconColor: colorScheme.primary,
      title: 'Registro Asistencia',
      onTap: () => Navigator.pushNamed(context, '/asistencia'),
    ));
    dashboardCards.add(_dashboardCard(
      context: context,
      icon: Icons.flash_on,
      iconColor: Colors.red.shade700,
      title: 'Falla Eléctrica',
      onTap: () => Navigator.pushNamed(context, '/falla_electrica'),
    ));
    dashboardCards.add(_dashboardCard(
      context: context,
      icon: Icons.assessment,
      iconColor: colorScheme.primary,
      title: 'Reportes',
      onTap: () {
        // TODO: Navegar a la página de Reportes
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sección Reportes (próximamente)')),
        );
      },
    ));
    dashboardCards.add(_dashboardCard(
      context: context,
      icon: Icons.flight_takeoff,
      iconColor: colorScheme.primary,
      title: 'Solicitud de Vacaciones',
      onTap: () {
        // TODO: Navegar a la página de Vacaciones
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sección Vacaciones (próximamente)')),
        );
      },
    ));

    // 2. Botón de MANTENIMIENTO (Solo para Admin y Superusuario)
    // (Según tu lógica: Luis y Alejandro)
    if (userRole == 'admin' || userRole == 'superusuario') {
      dashboardCards.add(_dashboardCard(
        context: context,
        icon: Icons.engineering,
        iconColor: Colors.blue.shade700,
        title: 'Mantenimiento',
        onTap: () => Navigator.pushNamed(context, '/mantenimiento_home'),
      ));
    }

    // 3. Botón de ADMIN USUARIOS (Solo para Superusuario)
    // (Según tu lógica: solo Alejandro)
    if (userRole == 'superusuario') {
      dashboardCards.add(_dashboardCard(
        context: context,
        icon: Icons.admin_panel_settings,
        iconColor: Colors.blueGrey.shade700,
        title: 'Admin Usuarios',
        onTap: () => Navigator.pushNamed(context, '/admin_usuarios'),
      ));
    }
    // --- FIN de la construcción dinámica ---

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/logo_tvt.jpg',
            fit: BoxFit.contain,
          ),
        ),
        // CAMBIO: Título personalizado con el nombre del usuario
        title: Text(userName.isNotEmpty ? userName : 'Panel Principal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      // CAMBIO: Mostrar indicador de carga mientras se obtienen los datos del usuario
      body: userProfile.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16.0),
              mainAxisSpacing: 16.0,
              crossAxisSpacing: 16.0,
              children: dashboardCards, // <-- Usamos la lista dinámica
            ),
    );
  }

  // --- (Función _dashboardCard sin cambios) ---
  Widget _dashboardCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  color: iconColor,
                  size: 50.0,
                ),
                const SizedBox(height: 8.0), // Espacio reducido
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0, // Tamaño ajustado
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

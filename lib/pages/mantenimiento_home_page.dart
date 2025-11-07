// lib/pages/mantenimiento_home_page.dart
// ignore_for_file: depend_on_referenced_packages // Ignoramos temporalmente

import 'package:flutter/material.dart';

class MantenimientoHomePage extends StatelessWidget {
  const MantenimientoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el tema para usar los colores definidos
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mantenimiento'),
        // El botón de regreso aparece automáticamente
      ),
      body: GridView.count(
        crossAxisCount: 2, // 2 columnas
        padding: const EdgeInsets.all(16.0),
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        children: <Widget>[
          // Tarjeta para Planta de Emergencia
          _buildMaintenanceCard(
            context: context,
            icon: Icons.flash_on_outlined, // Icono de rayo o similar
            iconColor: Colors.blue.shade700, // Azul (igual que en dashboard)
            title: 'Planta de Emergencia',
            onTap: () {
              // Navega a la pantalla específica de mantenimiento de planta
              Navigator.pushNamed(context, '/registrar_mantenimiento');
            },
          ),
          // Tarjeta para Aire Acondicionado
          _buildMaintenanceCard(
            context: context,
            icon: Icons.ac_unit_outlined, // Icono de copo de nieve
            iconColor: Colors.lightBlue.shade600, // Azul claro
            title: 'Aire Acondicionado',
            onTap: () {
              // Placeholder: Navegará a la pantalla de A/C
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Sección Aire Acondicionado (próximamente)')),
              );
            },
          ),
          // Tarjeta para Torre
          _buildMaintenanceCard(
            context: context,
            icon: Icons.cell_tower_outlined, // Icono de torre
            iconColor: Colors.grey.shade700, // Gris oscuro
            title: 'Torre',
            onTap: () {
              // Placeholder: Navegará a la pantalla de Torre
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sección Torre (próximamente)')),
              );
            },
          ),
          // Tarjeta para Instalación Eléctrica
          _buildMaintenanceCard(
            context: context,
            icon: Icons.electrical_services_outlined, // Icono eléctrico
            iconColor: Colors.orange.shade800, // Naranja oscuro
            title: 'Instalación Eléctrica',
            onTap: () {
              // Placeholder: Navegará a la pantalla Eléctrica
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Sección Eléctrica (próximamente)')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Función helper similar a la del Dashboard para crear las tarjetas
  Widget _buildMaintenanceCard({
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
                const SizedBox(height: 8.0),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0, // Tamaño consistente
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

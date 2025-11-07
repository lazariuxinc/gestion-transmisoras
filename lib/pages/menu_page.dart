// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Reportes', Icons.local_gas_station),
      ('Asistencia', Icons.how_to_reg),
      ('Novedades', Icons.flag),
      ('Insumos', Icons.inventory),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Menú principal')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: items.map((e) => _Card(title: e.$1, icon: e.$2)).toList(),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Card({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {},
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600))
            ],
          ),
        ),
      ),
    );
  }
}

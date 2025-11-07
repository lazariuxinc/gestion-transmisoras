// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';

// Definimos un modelo simple para cada nivel para mantener el código limpio.
class FuelLevel {
  final String label;
  final double value;

  const FuelLevel({required this.label, required this.value});
}

// Lista de los niveles que vamos a mostrar.
const List<FuelLevel> fuelLevels = [
  FuelLevel(label: 'Lleno (8/8)', value: 1.0),
  FuelLevel(label: 'Más de 3/4 (7/8)', value: 0.875),
  FuelLevel(label: '3/4 (6/8)', value: 0.75),
  FuelLevel(label: 'Más de 1/2 (5/8)', value: 0.625),
  FuelLevel(label: 'Medio (4/8)', value: 0.5),
  FuelLevel(label: 'Más de 1/4 (3/8)', value: 0.375),
  FuelLevel(label: '1/4 (2/8)', value: 0.25),
  FuelLevel(label: 'Reserva (1/8)', value: 0.125),
];

class FuelLevelSelector extends StatefulWidget {
  // Callback para notificar al widget padre del cambio de valor.
  final void Function(double value) onLevelChanged;
  final double initialValue;

  const FuelLevelSelector({
    super.key,
    required this.onLevelChanged,
    this.initialValue = 0.0, // Por defecto está vacío
  });

  @override
  State<FuelLevelSelector> createState() => _FuelLevelSelectorState();
}

class _FuelLevelSelectorState extends State<FuelLevelSelector> {
  late double _selectedLevel;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un Column para mostrar los niveles de arriba hacia abajo.
    return Column(
      // reversed: true para que el primer elemento de la lista (Lleno) aparezca arriba.
      children: fuelLevels.map((level) {
        final bool isSelected = _selectedLevel >= level.value;

        return GestureDetector(
          onTap: () {
            // Actualizamos el estado interno y notificamos al padre.
            setState(() {
              _selectedLevel = level.value;
            });
            widget.onLevelChanged(level.value);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[600] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: isSelected ? Colors.blue[800]! : Colors.grey[400]!,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                level.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

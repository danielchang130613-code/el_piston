import 'package:flutter/material.dart';

import '../../data/estado_orden.dart';

/// Etiqueta de color con el estado de una orden.
class EstadoChip extends StatelessWidget {
  final EstadoOrden estado;
  const EstadoChip(this.estado, {super.key});

  static Color color(EstadoOrden e) => switch (e) {
        EstadoOrden.recibida => Colors.blue.shade100,
        EstadoOrden.enDiagnostico => Colors.orange.shade100,
        EstadoOrden.enReparacion => Colors.amber.shade100,
        EstadoOrden.listaParaEntregar => Colors.green.shade100,
        EstadoOrden.entregada => Colors.grey.shade300,
        EstadoOrden.cancelada => Colors.red.shade100,
      };

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        estado.etiqueta,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
      backgroundColor: color(estado),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}

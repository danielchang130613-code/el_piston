import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../data/daos/ordenes_dao.dart';
import 'estado_chip.dart';

/// Tarjeta resumen de una orden (vehículo, cliente, problema, estado y total).
class OrdenCard extends StatelessWidget {
  final OrdenDetalle detalle;
  final VoidCallback onTap;
  const OrdenCard({super.key, required this.detalle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = detalle.orden;
    final v = detalle.vehiculo;
    final texto = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Orden #${o.id} · ${v.marca} ${v.modelo} (${v.matricula})',
                      style: texto.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  EstadoChip(detalle.estado),
                ],
              ),
              const SizedBox(height: 4),
              Text(detalle.cliente.nombre),
              Text(
                o.problemaReportado,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: texto.bodySmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.engineering,
                      size: 16, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${detalle.mecanico?.nombre ?? 'Sin asignar'} · '
                      '${fecha(o.fechaEntrada)}',
                      style: texto.bodySmall,
                    ),
                  ),
                  Text(dinero(detalle.total), style: texto.titleSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../data/daos/ordenes_dao.dart';
import '../ordenes/detalle_orden_view.dart';
import 'orden_card.dart';

/// Hoja inferior con el historial de servicios de un vehículo o de un cliente.
/// Si se pasa [deuda], muestra además el saldo pendiente.
void mostrarHistorial(
  BuildContext context, {
  required String titulo,
  required Stream<List<OrdenDetalle>> ordenes,
  Stream<double>? deuda,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _Historial(
        titulo: titulo,
        ordenes: ordenes,
        deuda: deuda,
        scroll: scroll,
      ),
    ),
  );
}

class _Historial extends StatelessWidget {
  final String titulo;
  final Stream<List<OrdenDetalle>> ordenes;
  final Stream<double>? deuda;
  final ScrollController scroll;
  const _Historial({
    required this.titulo,
    required this.ordenes,
    required this.deuda,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrdenDetalle>>(
      stream: ordenes,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = snap.data!;
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(titulo,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            if (deuda != null)
              StreamBuilder<double>(
                stream: deuda,
                builder: (context, d) {
                  final saldo = d.data ?? 0;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      saldo > 0.01
                          ? 'Saldo pendiente: ${dinero(saldo)}'
                          : 'Sin saldo pendiente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: saldo > 0.01 ? Colors.red : Colors.green,
                      ),
                    ),
                  );
                },
              ),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin órdenes registradas'),
              )
            else
              ...lista.map((d) => OrdenCard(
                    detalle: d,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DetalleOrdenView(ordenId: d.orden.id),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../../data/estado_orden.dart';
import '../ordenes/detalle_orden_view.dart';

class MecanicosView extends StatefulWidget {
  const MecanicosView({super.key});

  @override
  State<MecanicosView> createState() => _MecanicosViewState();
}

class _MecanicosViewState extends State<MecanicosView> {
  late final Stream<List<MecanicoConCarga>> _carga;

  @override
  void initState() {
    super.initState();
    _carga = context.read<AppDatabase>().ordenesDao.observarCargaPorMecanico();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mecánicos y carga de trabajo')),
      body: StreamBuilder<List<MecanicoConCarga>>(
        stream: _carga,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(child: Text('No hay mecánicos registrados'));
          }
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [for (final m in lista) _MecanicoCard(carga: m)],
          );
        },
      ),
    );
  }
}

class _MecanicoCard extends StatelessWidget {
  final MecanicoConCarga carga;
  const _MecanicoCard({required this.carga});

  @override
  Widget build(BuildContext context) {
    final alta = carga.abiertas > cargaAltaMecanico;
    final color = alta ? Colors.red : Colors.green;
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(carga.mecanico.nombre),
        subtitle: Text('Órdenes abiertas asignadas: ${carga.abiertas}'),
        trailing: Icon(alta ? Icons.warning : Icons.check_circle, color: color),
        children: [
          if (carga.ordenes.isEmpty)
            const ListTile(title: Text('Sin órdenes abiertas')),
          for (final o in carga.ordenes)
            ListTile(
              dense: true,
              title: Text('Orden #${o.id} · ${EstadoOrden.desdeValor(o.estado).etiqueta}'),
              subtitle: Text(
                '${o.problemaReportado}\nEntrada: ${fecha(o.fechaEntrada)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DetalleOrdenView(ordenId: o.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

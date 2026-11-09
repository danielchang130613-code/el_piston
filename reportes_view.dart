import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../ordenes/detalle_orden_view.dart';

class ReportesView extends StatefulWidget {
  const ReportesView({super.key});

  @override
  State<ReportesView> createState() => _ReportesViewState();
}

class _ReportesViewState extends State<ReportesView> {
  late final OrdenesDao _dao;
  late final Stream<List<SaldoCliente>> _saldos;
  late final Stream<List<Repuesto>> _bajos;
  late DateTimeRange _rango;
  late Future<ResumenPeriodo> _resumen;

  @override
  void initState() {
    super.initState();
    _dao = context.read<AppDatabase>().ordenesDao;
    _saldos = _dao.observarSaldosPorCliente();
    _bajos = _dao.observarRepuestosBajos();
    final ahora = DateTime.now();
    _rango = DateTimeRange(
      start: DateTime(ahora.year, ahora.month, 1),
      end: DateTime(ahora.year, ahora.month, ahora.day),
    );
    _resumen = _dao.resumenPeriodo(_rango.start, _rango.end);
  }

  Future<void> _elegirPeriodo() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _rango,
      helpText: 'Período a consultar',
    );
    if (r == null) return;
    setState(() {
      _rango = r;
      _resumen = _dao.resumenPeriodo(r.start, r.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: tema.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Período: ${fecha(_rango.start)} – ${fecha(_rango.end)}',
                          style: tema.textTheme.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: const Text('Cambiar'),
                        onPressed: _elegirPeriodo,
                      ),
                    ],
                  ),
                  FutureBuilder<ResumenPeriodo>(
                    future: _resumen,
                    builder: (context, snap) {
                      final r = snap.data;
                      return Column(
                        children: [
                          _linea('Facturado', r == null ? '…' : dinero(r.facturado),
                              grande: true),
                          _linea('Cobrado', r == null ? '…' : dinero(r.cobrado)),
                          _linea('Órdenes', r == null ? '…' : '${r.ordenes}'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Clientes con saldo pendiente', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<SaldoCliente>>(
            stream: _saldos,
            builder: (context, snap) {
              final lista = snap.data ?? const <SaldoCliente>[];
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Sin saldos pendientes'),
                );
              }
              return Column(
                children: [
                  for (final s in lista)
                    Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.person),
                        title: Text(s.cliente.nombre),
                        subtitle: Text('Tel: ${s.cliente.telefono}'),
                        trailing: Text(
                          dinero(s.pendiente),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          for (final e in s.ordenes)
                            ListTile(
                              dense: true,
                              title: Text(
                                'Orden #${e.orden.id} · ${e.vehiculo.matricula}',
                              ),
                              subtitle: Text('Pagado: ${dinero(e.pagado)}'),
                              trailing: Text(dinero(e.saldo)),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DetalleOrdenView(ordenId: e.orden.id),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Repuestos por agotarse', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<Repuesto>>(
            stream: _bajos,
            builder: (context, snap) {
              final lista = snap.data ?? const <Repuesto>[];
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Inventario en buen nivel'),
                );
              }
              return Column(
                children: [
                  for (final r in lista)
                    ListTile(
                      leading:
                          const Icon(Icons.warning, color: Colors.orange),
                      title: Text(r.nombre),
                      subtitle: Text('Código: ${r.codigo}'),
                      trailing: Text('${r.existencias} uds'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _linea(String k, String v, {bool grande = false}) {
    final estilo = TextStyle(
      fontSize: grande ? 22 : 15,
      fontWeight: grande ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: estilo), Text(v, style: estilo)],
      ),
    );
  }
}

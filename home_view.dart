import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../clientes/clientes_view.dart';
import '../inventario/inventario_view.dart';
import '../mecanicos/mecanicos_view.dart';
import '../ordenes/nueva_orden_view.dart';
import '../ordenes/ordenes_view.dart';
import '../reportes/reportes_view.dart';
import '../vehiculos/vehiculos_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final Stream<int> _abiertas;
  late final Stream<List<OrdenConSaldo>> _saldos;
  late final Stream<List<Repuesto>> _bajos;

  @override
  void initState() {
    super.initState();
    final dao = context.read<AppDatabase>().ordenesDao;
    _abiertas = dao.observarConteoAbiertas();
    _saldos = dao.observarOrdenesConSaldo();
    _bajos = dao.observarRepuestosBajos();
  }

  void _ir(Widget destino) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => destino),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller El Pistón'),
        backgroundColor: tema.colorScheme.primary,
        foregroundColor: tema.colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Panel de Control', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<int>(
                  stream: _abiertas,
                  builder: (context, s) => _Indicador(
                    icono: Icons.build_circle,
                    valor: '${s.data ?? 0}',
                    etiqueta: 'Órdenes abiertas',
                    onTap: () => _ir(const OrdenesView()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<List<OrdenConSaldo>>(
                  stream: _saldos,
                  builder: (context, s) {
                    final total = (s.data ?? const <OrdenConSaldo>[])
                        .fold<double>(0, (a, e) => a + e.saldo);
                    return _Indicador(
                      icono: Icons.attach_money,
                      valor: dinero(total),
                      etiqueta: 'Por cobrar',
                      color: total > 0.01 ? Colors.red : null,
                      onTap: () => _ir(const ReportesView()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<List<Repuesto>>(
                  stream: _bajos,
                  builder: (context, s) {
                    final n = (s.data ?? const <Repuesto>[]).length;
                    return _Indicador(
                      icono: Icons.warning_amber,
                      valor: '$n',
                      etiqueta: 'Repuestos bajos',
                      color: n > 0 ? Colors.orange.shade800 : null,
                      onTap: () => _ir(const InventarioView()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nueva orden de servicio'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => _ir(const NuevaOrdenView()),
          ),
          const SizedBox(height: 16),
          _botonMenu('Órdenes de Servicio', Icons.build_circle,
              () => _ir(const OrdenesView())),
          _botonMenu('Clientes', Icons.people, () => _ir(const ClientesView())),
          _botonMenu('Vehículos', Icons.directions_car,
              () => _ir(const VehiculosView())),
          _botonMenu('Inventario de Repuestos', Icons.inventory,
              () => _ir(const InventarioView())),
          _botonMenu('Mecánicos (Carga)', Icons.engineering,
              () => _ir(const MecanicosView())),
          _botonMenu('Reportes y Saldos', Icons.bar_chart,
              () => _ir(const ReportesView())),
        ],
      ),
    );
  }

  Widget _botonMenu(String texto, IconData icono, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono,
            color: Theme.of(context).colorScheme.primary, size: 30),
        title: Text(texto, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color? color;
  final VoidCallback onTap;
  const _Indicador({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icono, color: c),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  valor,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: c),
                ),
              ),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

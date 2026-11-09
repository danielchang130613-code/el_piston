import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../widgets/historial_sheet.dart';

class ClientesView extends StatefulWidget {
  const ClientesView({super.key});

  @override
  State<ClientesView> createState() => _ClientesViewState();
}

class _ClientesViewState extends State<ClientesView> {
  late final OrdenesDao _dao;
  late final Stream<List<Cliente>> _clientes;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _dao = context.read<AppDatabase>().ordenesDao;
    _clientes = _dao.observarClientes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes y vehículos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar por nombre o teléfono',
              ),
              onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Cliente>>(
              stream: _clientes,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lista = snap.data!
                    .where((c) =>
                        c.nombre.toLowerCase().contains(_busqueda) ||
                        c.telefono.contains(_busqueda))
                    .toList();
                if (lista.isEmpty) {
                  return const Center(child: Text('No hay clientes para mostrar'));
                }
                return ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) => _ClienteTile(cliente: lista[i], dao: _dao),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  final Cliente cliente;
  final OrdenesDao dao;
  const _ClienteTile({required this.cliente, required this.dao});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.person),
      title: Text(cliente.nombre),
      subtitle: Text('Tel: ${cliente.telefono}'),
      children: [
        if (cliente.direccion != null)
          ListTile(
            dense: true,
            leading: const Icon(Icons.place),
            title: Text(cliente.direccion!),
          ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Historial de servicios y saldo'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => mostrarHistorial(
            context,
            titulo: 'Historial de ${cliente.nombre}',
            ordenes: dao.observarHistorialCliente(cliente.id),
            deuda: dao.observarDeudaCliente(cliente.id),
          ),
        ),
        StreamBuilder<List<Vehiculo>>(
          stream: dao.observarVehiculosDeCliente(cliente.id),
          builder: (context, snap) {
            final vehiculos = snap.data ?? const <Vehiculo>[];
            if (vehiculos.isEmpty) {
              return const ListTile(title: Text('Sin vehículos'));
            }
            return Column(
              children: [
                for (final v in vehiculos)
                  ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: Text('${v.marca} ${v.modelo} (${v.matricula})'),
                    subtitle: Text('Año: ${v.anio} · Km: ${v.kilometraje}'),
                    onTap: () => mostrarHistorial(
                      context,
                      titulo: 'Historial de ${v.matricula}',
                      ordenes: dao.observarHistorialVehiculo(v.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

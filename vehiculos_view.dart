import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../widgets/historial_sheet.dart';

class VehiculosView extends StatefulWidget {
  const VehiculosView({super.key});

  @override
  State<VehiculosView> createState() => _VehiculosViewState();
}

class _VehiculosViewState extends State<VehiculosView> {
  late final OrdenesDao _dao;
  late final Stream<List<VehiculoConCliente>> _vehiculos;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _dao = context.read<AppDatabase>().ordenesDao;
    _vehiculos = _dao.observarVehiculos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehículos registrados')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar por matrícula, marca o modelo',
              ),
              onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<VehiculoConCliente>>(
              stream: _vehiculos,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lista = snap.data!.where((e) {
                  final v = e.vehiculo;
                  return v.matricula.toLowerCase().contains(_busqueda) ||
                      v.marca.toLowerCase().contains(_busqueda) ||
                      v.modelo.toLowerCase().contains(_busqueda);
                }).toList();
                if (lista.isEmpty) {
                  return const Center(child: Text('No hay vehículos para mostrar'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final v = lista[i].vehiculo;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.directions_car, size: 36),
                        title: Text('${v.marca} ${v.modelo} (${v.matricula})'),
                        subtitle: Text(
                          'Dueño: ${lista[i].cliente.nombre}\n'
                          'Año: ${v.anio} · Km: ${v.kilometraje}',
                        ),
                        isThreeLine: true,
                        onTap: () => mostrarHistorial(
                          context,
                          titulo: 'Historial de ${v.matricula}',
                          ordenes: _dao.observarHistorialVehiculo(v.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

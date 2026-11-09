import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constantes.dart';
import '../../core/formato.dart';
import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../../data/taller_exception.dart';
import 'dialogos_inventario.dart';

class InventarioView extends StatefulWidget {
  const InventarioView({super.key});

  @override
  State<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends State<InventarioView> {
  late final OrdenesDao _dao;
  late final Stream<List<Repuesto>> _inventario;

  @override
  void initState() {
    super.initState();
    _dao = context.read<AppDatabase>().ordenesDao;
    _inventario = _dao.observarInventario();
  }

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await accion();
      messenger.showSnackBar(SnackBar(content: Text(exito)));
    } on TallerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    }
  }

  Future<void> _nuevo() async {
    final r = await showDialog<RepuestoNuevoInput>(
      context: context,
      builder: (_) => const DialogoRepuestoNuevo(),
    );
    if (r == null) return;
    await _ejecutar(
      () => _dao.insertarRepuesto(
        codigo: r.codigo,
        nombre: r.nombre,
        precioVenta: r.precio,
        existencias: r.existencias,
      ),
      'Repuesto agregado',
    );
  }

  Future<void> _reponer(Repuesto rep) async {
    final cantidad = await showDialog<int>(
      context: context,
      builder: (_) => DialogoReponer(nombre: rep.nombre),
    );
    if (cantidad == null) return;
    await _ejecutar(
      () => _dao.reponerStock(rep.id, cantidad),
      'Stock actualizado',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario de repuestos')),
      body: StreamBuilder<List<Repuesto>>(
        stream: _inventario,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final repuestos = snap.data!;
          if (repuestos.isEmpty) {
            return const Center(child: Text('Inventario vacío'));
          }
          final bajos =
              repuestos.where((r) => r.existencias <= umbralStockBajo).length;
          return Column(
            children: [
              if (bajos > 0)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$bajos repuesto(s) con $umbralStockBajo o menos '
                          'unidades. Toca uno para reponer.',
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: repuestos.length,
                  itemBuilder: (context, index) {
                    final rep = repuestos[index];
                    final bajo = rep.existencias <= umbralStockBajo;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        onTap: () => _reponer(rep),
                        leading: Icon(
                          Icons.inventory_2,
                          color: bajo ? Colors.red : Colors.green,
                          size: 32,
                        ),
                        title: Text(rep.nombre),
                        subtitle: Text(
                          'Código: ${rep.codigo}\n'
                          'Precio: ${dinero(rep.precioVenta)}',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${rep.existencias}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: bajo ? Colors.red : null,
                              ),
                            ),
                            const Text('uds', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nuevo repuesto'),
        onPressed: _nuevo,
      ),
    );
  }
}

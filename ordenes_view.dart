import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../data/app_database.dart';
import '../../data/estado_orden.dart';
import '../../viewmodels/ordenes_viewmodel.dart';
import '../widgets/orden_card.dart';
import 'detalle_orden_view.dart';
import 'nueva_orden_view.dart';

class OrdenesView extends StatelessWidget {
  const OrdenesView({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return ChangeNotifierProvider(
      create: (_) => OrdenesViewModel(db.ordenesDao),
      child: const _OrdenesBody(),
    );
  }
}

class _OrdenesBody extends StatelessWidget {
  const _OrdenesBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdenesViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Órdenes abiertas'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                'Por cobrar: ${dinero(vm.totalPorCobrar)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _Filtros(vm: vm),
          Expanded(child: _Lista(vm: vm)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nueva orden'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const NuevaOrdenView()),
        ),
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  final OrdenesViewModel vm;
  const _Filtros({required this.vm});

  @override
  Widget build(BuildContext context) {
    final abiertos = EstadoOrden.values.where((e) => !e.esFinal);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Todas (${vm.totalAbiertas})'),
              selected: vm.filtro == null,
              onSelected: (_) => vm.filtrarPor(null),
            ),
          ),
          for (final e in abiertos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${e.etiqueta} (${vm.cantidadEn(e)})'),
                selected: vm.filtro == e,
                onSelected: (_) => vm.filtrarPor(vm.filtro == e ? null : e),
              ),
            ),
        ],
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  final OrdenesViewModel vm;
  const _Lista({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return Center(child: Text(vm.error!));
    }
    final lista = vm.ordenes;
    if (lista.isEmpty) {
      return const Center(child: Text('No hay órdenes abiertas'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final d = lista[index];
        return OrdenCard(
          detalle: d,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => DetalleOrdenView(ordenId: d.orden.id),
            ),
          ),
        );
      },
    );
  }
}

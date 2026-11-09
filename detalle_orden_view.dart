import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../../data/estado_orden.dart';
import '../../data/taller_exception.dart';
import '../widgets/estado_chip.dart';
import 'dialogos_orden.dart';

class DetalleOrdenView extends StatefulWidget {
  final int ordenId;
  const DetalleOrdenView({super.key, required this.ordenId});

  @override
  State<DetalleOrdenView> createState() => _DetalleOrdenViewState();
}

class _DetalleOrdenViewState extends State<DetalleOrdenView> {
  late final OrdenesDao _dao;
  late final Stream<OrdenDetalle?> _orden;
  late final Stream<List<Trabajo>> _trabajos;
  late final Stream<List<RepuestoUsadoDetalle>> _repuestos;
  late final Stream<List<Pago>> _pagos;

  @override
  void initState() {
    super.initState();
    _dao = context.read<AppDatabase>().ordenesDao;
    _orden = _dao.observarOrdenDetalle(widget.ordenId);
    _trabajos = _dao.observarTrabajos(widget.ordenId);
    _repuestos = _dao.observarRepuestosUsados(widget.ordenId);
    _pagos = _dao.observarPagos(widget.ordenId);
  }

  /// Ejecuta una operación de negocio mostrando el resultado en un SnackBar.
  Future<void> _ejecutar(Future<void> Function() accion, {String? exito}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await accion();
      if (exito != null) {
        messenger.showSnackBar(SnackBar(content: Text(exito)));
      }
    } on TallerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    }
  }

  Future<void> _cambiarEstado(EstadoOrden nuevo) async {
    if (nuevo.esFinal) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('¿Marcar como ${nuevo.etiqueta.toLowerCase()}?'),
          content: Text(
            nuevo == EstadoOrden.cancelada
                ? 'Los repuestos usados volverán al inventario y la orden '
                    'ya no se podrá modificar.'
                : 'Después de entregada la orden solo admitirá pagos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _ejecutar(
      () => _dao.cambiarEstado(widget.ordenId, nuevo),
      exito: 'Estado actualizado: ${nuevo.etiqueta}',
    );
  }

  Future<void> _agregarTrabajo() async {
    final r = await showDialog<TrabajoInput>(
      context: context,
      builder: (_) => const DialogoTrabajo(),
    );
    if (r == null) return;
    await _ejecutar(
      () => _dao.insertarTrabajo(
        ordenId: widget.ordenId,
        descripcion: r.descripcion,
        precio: r.precio,
      ),
      exito: 'Trabajo agregado',
    );
  }

  Future<void> _usarRepuesto() async {
    final messenger = ScaffoldMessenger.of(context);
    final inventario = await _dao.observarInventario().first;
    if (!mounted) return;
    if (inventario.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay repuestos en el inventario')),
      );
      return;
    }
    final r = await showDialog<RepuestoInput>(
      context: context,
      builder: (_) => DialogoRepuesto(repuestos: inventario),
    );
    if (r == null) return;
    await _ejecutar(
      () => _dao.usarRepuesto(
        ordenId: widget.ordenId,
        repuestoId: r.repuesto.id,
        cantidad: r.cantidad,
      ),
      exito: 'Repuesto agregado a la orden',
    );
  }

  Future<void> _registrarPago(double saldo) async {
    final r = await showDialog<PagoInput>(
      context: context,
      builder: (_) => DialogoPago(saldo: saldo),
    );
    if (r == null) return;
    await _ejecutar(
      () => _dao.registrarPago(
        ordenId: widget.ordenId,
        monto: r.monto,
        metodo: r.metodo,
      ),
      exito: 'Pago registrado',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Orden #${widget.ordenId}')),
      body: StreamBuilder<OrdenDetalle?>(
        stream: _orden,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (d == null) {
            return const Center(child: Text('Orden no encontrada'));
          }
          final abierta = !d.estado.esFinal;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _cabecera(d),
              _seccionTrabajos(abierta),
              _seccionRepuestos(abierta),
              _seccionPagos(d),
            ],
          );
        },
      ),
    );
  }

  Widget _cabecera(OrdenDetalle d) {
    final o = d.orden;
    final v = d.vehiculo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${v.marca} ${v.modelo} · ${v.matricula}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Año ${v.anio} · ${v.kilometraje} km'),
            const SizedBox(height: 8),
            Text('Cliente: ${d.cliente.nombre} (${d.cliente.telefono})'),
            Text('Mecánico: ${d.mecanico?.nombre ?? 'Sin asignar'}'),
            Text('Entrada: ${fechaHora(o.fechaEntrada)}'),
            if (o.fechaSalida != null)
              Text('Salida: ${fechaHora(o.fechaSalida!)}'),
            const SizedBox(height: 8),
            Text('Problema reportado:',
                style: Theme.of(context).textTheme.labelLarge),
            Text(o.problemaReportado),
            const SizedBox(height: 12),
            if (d.estado.esFinal)
              Align(
                alignment: Alignment.centerLeft,
                child: EstadoChip(d.estado),
              )
            else
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Estado'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<EstadoOrden>(
                    value: d.estado,
                    isExpanded: true,
                    isDense: true,
                    items: EstadoOrden.values
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e.etiqueta)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _cambiarEstado(v);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _seccionTrabajos(bool abierta) {
    return _Seccion(
      titulo: 'Trabajos realizados',
      accion: abierta
          ? TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
              onPressed: _agregarTrabajo,
            )
          : null,
      child: StreamBuilder<List<Trabajo>>(
        stream: _trabajos,
        builder: (context, snap) {
          final lista = snap.data ?? const <Trabajo>[];
          if (lista.isEmpty) return const Text('Aún no hay trabajos');
          return Column(
            children: [
              for (final t in lista)
                _fila(t.descripcion, dinero(t.precio)),
              const Divider(),
              _fila('Mano de obra',
                  dinero(lista.fold<double>(0, (a, t) => a + t.precio)),
                  negrita: true),
            ],
          );
        },
      ),
    );
  }

  Widget _seccionRepuestos(bool abierta) {
    return _Seccion(
      titulo: 'Repuestos usados',
      accion: abierta
          ? TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Usar'),
              onPressed: _usarRepuesto,
            )
          : null,
      child: StreamBuilder<List<RepuestoUsadoDetalle>>(
        stream: _repuestos,
        builder: (context, snap) {
          final lista = snap.data ?? const <RepuestoUsadoDetalle>[];
          if (lista.isEmpty) return const Text('Aún no se usaron repuestos');
          return Column(
            children: [
              for (final r in lista)
                _fila(
                  '${r.uso.cantidad} × ${r.repuesto.nombre}',
                  dinero(r.subtotal),
                ),
              const Divider(),
              _fila('Repuestos',
                  dinero(lista.fold<double>(0, (a, r) => a + r.subtotal)),
                  negrita: true),
            ],
          );
        },
      ),
    );
  }

  Widget _seccionPagos(OrdenDetalle d) {
    final cancelada = d.estado == EstadoOrden.cancelada;
    return StreamBuilder<List<Pago>>(
      stream: _pagos,
      builder: (context, snap) {
        final pagos = snap.data ?? const <Pago>[];
        final pagado = pagos.fold<double>(0, (a, p) => a + p.monto);
        final saldo = d.total - pagado;
        final debe = saldo > 0.01;
        return _Seccion(
          titulo: 'Cobro',
          accion: (!cancelada && debe)
              ? TextButton.icon(
                  icon: const Icon(Icons.payments),
                  label: const Text('Registrar pago'),
                  onPressed: () => _registrarPago(saldo),
                )
              : null,
          child: Column(
            children: [
              _fila('Mano de obra', dinero(d.orden.totalManoObra)),
              _fila('Repuestos', dinero(d.orden.totalRepuestos)),
              const Divider(),
              _fila('TOTAL', dinero(d.total), negrita: true),
              _fila('Pagado', dinero(pagado)),
              _fila(
                'Saldo pendiente',
                dinero(saldo < 0 ? 0 : saldo),
                negrita: true,
                color: debe ? Colors.red : Colors.green,
              ),
              if (pagos.isNotEmpty) ...[
                const Divider(),
                for (final p in pagos)
                  _fila(
                    '${fecha(p.fecha)} · ${p.metodo ?? 'Pago'}',
                    dinero(p.monto),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _fila(String k, String v, {bool negrita = false, Color? color}) {
    final estilo = TextStyle(
      fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(k, style: estilo)),
          Text(v, style: estilo),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final Widget? accion;
  final Widget child;
  const _Seccion({required this.titulo, required this.child, this.accion});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(titulo,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (accion != null) accion!,
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

import 'package:drift/drift.dart';

import '../../core/constantes.dart';
import '../app_database.dart';
import '../estado_orden.dart';
import '../tables.dart';
import '../taller_exception.dart';

part 'ordenes_dao.g.dart';

@DriftAccessor(tables: [
  Ordenes,
  Vehiculos,
  Clientes,
  Mecanicos,
  Trabajos,
  Repuestos,
  RepuestosUsados,
  Pagos,
])
class OrdenesDao extends DatabaseAccessor<AppDatabase> with _$OrdenesDaoMixin {
  OrdenesDao(super.attachedDatabase);

  static const double _tolerancia = 0.005;

  // ═══════════════════════════════════════════════════════════════
  // 1. ÓRDENES (abiertas, detalle, estado)
  // ═══════════════════════════════════════════════════════════════

  /// Consulta base: orden + vehículo + cliente + mecánico (opcional).
  Selectable<TypedResult> _consultaDetalle({Expression<bool>? filtro}) {
    final query = select(ordenes).join([
      innerJoin(vehiculos, vehiculos.id.equalsExp(ordenes.vehiculoId)),
      innerJoin(clientes, clientes.id.equalsExp(vehiculos.clienteId)),
      leftOuterJoin(mecanicos, mecanicos.id.equalsExp(ordenes.mecanicoId)),
    ]);
    if (filtro != null) query.where(filtro);
    query.orderBy([OrderingTerm.desc(ordenes.fechaEntrada)]);
    return query;
  }

  OrdenDetalle _aDetalle(TypedResult r) => OrdenDetalle(
        orden: r.readTable(ordenes),
        vehiculo: r.readTable(vehiculos),
        cliente: r.readTable(clientes),
        mecanico: r.readTableOrNull(mecanicos),
      );

  /// Órdenes que NO están entregadas ni canceladas.
  Stream<List<Orden>> observarAbiertas() {
    return (select(ordenes)
          ..where((o) => o.estado.isNotIn(EstadoOrden.valoresFinales))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaEntrada)]))
        .watch();
  }

  /// Órdenes abiertas con vehículo, cliente y mecánico ya resueltos.
  Stream<List<OrdenDetalle>> observarAbiertasDetalle() {
    return _consultaDetalle(
      filtro: ordenes.estado.isNotIn(EstadoOrden.valoresFinales),
    ).watch().map((rows) => rows.map(_aDetalle).toList());
  }

  Stream<int> observarConteoAbiertas() {
    final cuenta = ordenes.id.count();
    return (selectOnly(ordenes)
          ..addColumns([cuenta])
          ..where(ordenes.estado.isNotIn(EstadoOrden.valoresFinales)))
        .map((r) => r.read(cuenta) ?? 0)
        .watchSingle();
  }

  Stream<OrdenDetalle?> observarOrdenDetalle(int id) {
    return _consultaDetalle(filtro: ordenes.id.equals(id))
        .watchSingleOrNull()
        .map((r) => r == null ? null : _aDetalle(r));
  }

  Future<Orden?> obtenerOrden(int id) {
    return (select(ordenes)..where((o) => o.id.equals(id))).getSingleOrNull();
  }

  /// Cambia el estado de una orden aplicando las reglas del taller:
  /// - una orden entregada/cancelada ya no se puede modificar,
  /// - al entregar se registra la fecha de salida,
  /// - al cancelar, los repuestos usados vuelven al inventario.
  Future<void> cambiarEstado(int ordenId, EstadoOrden nuevo) {
    return transaction(() async {
      final orden = await obtenerOrden(ordenId);
      if (orden == null) {
        throw TallerException('La orden #$ordenId no existe');
      }
      final actual = EstadoOrden.desdeValor(orden.estado);
      if (actual == nuevo) return;
      if (actual.esFinal) {
        throw TallerException(
          'La orden #$ordenId está ${actual.etiqueta.toLowerCase()} '
          'y ya no se puede modificar',
        );
      }
      if (nuevo == EstadoOrden.cancelada) {
        await _devolverRepuestos(ordenId);
      }
      await (update(ordenes)..where((o) => o.id.equals(ordenId))).write(
        OrdenesCompanion(
          estado: Value(nuevo.valor),
          fechaSalida: nuevo == EstadoOrden.entregada
              ? Value(DateTime.now())
              : const Value.absent(),
        ),
      );
    });
  }

  Future<void> _devolverRepuestos(int ordenId) async {
    final usados = await (select(repuestosUsados)
          ..where((u) => u.ordenId.equals(ordenId)))
        .get();
    for (final u in usados) {
      final rep = await (select(repuestos)
            ..where((r) => r.id.equals(u.repuestoId)))
          .getSingle();
      await (update(repuestos)..where((r) => r.id.equals(u.repuestoId))).write(
        RepuestosCompanion(existencias: Value(rep.existencias + u.cantidad)),
      );
    }
  }

  Future<Orden> _exigirOrdenAbierta(int ordenId) async {
    final orden = await obtenerOrden(ordenId);
    if (orden == null) {
      throw TallerException('La orden #$ordenId no existe');
    }
    final estado = EstadoOrden.desdeValor(orden.estado);
    if (estado.esFinal) {
      throw TallerException(
        'La orden #$ordenId está ${estado.etiqueta.toLowerCase()} '
        'y no admite cambios',
      );
    }
    return orden;
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. INGRESO DE UN VEHÍCULO (cliente + vehículo + orden) EN TRANSACCIÓN
  // ═══════════════════════════════════════════════════════════════

  Future<Cliente?> buscarClientePorTelefono(String telefono) {
    return (select(clientes)
          ..where((c) => c.telefono.equals(telefono.trim()))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Vehiculo?> buscarVehiculoPorMatricula(String matricula) {
    return (select(vehiculos)
          ..where((v) => v.matricula.equals(matricula.trim().toUpperCase()))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Crea (o reutiliza) el cliente y el vehículo y registra la orden.
  /// Devuelve el id de la orden creada.
  Future<int> registrarIngreso({
    required String nombre,
    required String telefono,
    String? direccion,
    required String matricula,
    required String marca,
    required String modelo,
    required int anio,
    required int kilometraje,
    required String problema,
    int? mecanicoId,
  }) {
    return transaction(() async {
      final existente = await buscarClientePorTelefono(telefono);
      final dir = (direccion == null || direccion.trim().isEmpty)
          ? null
          : direccion.trim();
      final clienteId = existente?.id ??
          await into(clientes).insert(ClientesCompanion.insert(
            nombre: nombre.trim(),
            telefono: telefono.trim(),
            direccion: Value(dir),
          ));

      final placa = matricula.trim().toUpperCase();
      final vehiculoExistente = await buscarVehiculoPorMatricula(placa);
      final int vehiculoId;
      if (vehiculoExistente != null) {
        vehiculoId = vehiculoExistente.id;
        // Se guarda el kilometraje con el que llegó esta vez.
        await (update(vehiculos)..where((v) => v.id.equals(vehiculoId)))
            .write(VehiculosCompanion(kilometraje: Value(kilometraje)));
      } else {
        vehiculoId = await into(vehiculos).insert(VehiculosCompanion.insert(
          clienteId: clienteId,
          matricula: placa,
          marca: marca.trim(),
          modelo: modelo.trim(),
          anio: anio,
          kilometraje: Value(kilometraje),
        ));
      }

      return into(ordenes).insert(OrdenesCompanion.insert(
        vehiculoId: vehiculoId,
        mecanicoId: Value(mecanicoId),
        fechaEntrada: DateTime.now(),
        problemaReportado: problema.trim(),
      ));
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. CARGA DE TRABAJO POR MECÁNICO
  // ═══════════════════════════════════════════════════════════════

  Stream<List<Mecanico>> observarMecanicos() {
    return (select(mecanicos)
          ..where((m) => m.activo.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.nombre)]))
        .watch();
  }

  /// Cada mecánico activo con sus órdenes abiertas.
  Stream<List<MecanicoConCarga>> observarCargaPorMecanico() {
    final query = select(mecanicos).join([
      leftOuterJoin(
        ordenes,
        ordenes.mecanicoId.equalsExp(mecanicos.id) &
            ordenes.estado.isNotIn(EstadoOrden.valoresFinales),
      ),
    ])
      ..where(mecanicos.activo.equals(true))
      ..orderBy([OrderingTerm.asc(mecanicos.nombre)]);

    return query.watch().map((rows) {
      final mapa = <int, MecanicoConCarga>{};
      for (final row in rows) {
        final m = row.readTable(mecanicos);
        final o = row.readTableOrNull(ordenes);
        final carga = mapa.putIfAbsent(
          m.id,
          () => MecanicoConCarga(mecanico: m, ordenes: <Orden>[]),
        );
        if (o != null) carga.ordenes.add(o);
      }
      return mapa.values.toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. HISTORIAL POR VEHÍCULO Y POR CLIENTE
  // ═══════════════════════════════════════════════════════════════

  Stream<List<OrdenDetalle>> observarHistorialVehiculo(int vehiculoId) {
    return _consultaDetalle(filtro: ordenes.vehiculoId.equals(vehiculoId))
        .watch()
        .map((rows) => rows.map(_aDetalle).toList());
  }

  Stream<List<OrdenDetalle>> observarHistorialCliente(int clienteId) {
    return _consultaDetalle(filtro: vehiculos.clienteId.equals(clienteId))
        .watch()
        .map((rows) => rows.map(_aDetalle).toList());
  }

  Stream<List<Cliente>> observarClientes() {
    return (select(clientes)..orderBy([(c) => OrderingTerm.asc(c.nombre)]))
        .watch();
  }

  Stream<List<Vehiculo>> observarVehiculosDeCliente(int clienteId) {
    return (select(vehiculos)
          ..where((v) => v.clienteId.equals(clienteId))
          ..orderBy([(v) => OrderingTerm.asc(v.matricula)]))
        .watch();
  }

  Stream<List<VehiculoConCliente>> observarVehiculos() {
    final query = select(vehiculos).join([
      innerJoin(clientes, clientes.id.equalsExp(vehiculos.clienteId)),
    ])
      ..orderBy([OrderingTerm.asc(vehiculos.matricula)]);
    return query.watch().map((rows) => rows
        .map((r) => VehiculoConCliente(
              vehiculo: r.readTable(vehiculos),
              cliente: r.readTable(clientes),
            ))
        .toList());
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. TRABAJOS, REPUESTOS USADOS Y PAGOS DE UNA ORDEN
  // ═══════════════════════════════════════════════════════════════

  Stream<List<Trabajo>> observarTrabajos(int ordenId) {
    return (select(trabajos)
          ..where((t) => t.ordenId.equals(ordenId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  Stream<List<RepuestoUsadoDetalle>> observarRepuestosUsados(int ordenId) {
    final query = select(repuestosUsados).join([
      innerJoin(repuestos, repuestos.id.equalsExp(repuestosUsados.repuestoId)),
    ])
      ..where(repuestosUsados.ordenId.equals(ordenId))
      ..orderBy([OrderingTerm.asc(repuestosUsados.id)]);
    return query.watch().map((rows) => rows
        .map((r) => RepuestoUsadoDetalle(
              uso: r.readTable(repuestosUsados),
              repuesto: r.readTable(repuestos),
            ))
        .toList());
  }

  Stream<List<Pago>> observarPagos(int ordenId) {
    return (select(pagos)
          ..where((p) => p.ordenId.equals(ordenId))
          ..orderBy([(p) => OrderingTerm.asc(p.fecha)]))
        .watch();
  }

  Future<int> insertarTrabajo({
    required int ordenId,
    required String descripcion,
    required double precio,
  }) async {
    if (descripcion.trim().isEmpty) {
      throw const TallerException('La descripción del trabajo es obligatoria');
    }
    if (precio <= 0) {
      throw const TallerException('El precio debe ser mayor que 0');
    }
    return transaction(() async {
      await _exigirOrdenAbierta(ordenId);
      final id = await into(trabajos).insert(TrabajosCompanion.insert(
        ordenId: ordenId,
        descripcion: descripcion.trim(),
        precio: precio,
      ));
      final lista = await (select(trabajos)
            ..where((t) => t.ordenId.equals(ordenId)))
          .get();
      final total = lista.fold<double>(0, (a, t) => a + t.precio);
      await (update(ordenes)..where((o) => o.id.equals(ordenId)))
          .write(OrdenesCompanion(totalManoObra: Value(total)));
      return id;
    });
  }

  /// Usa un repuesto en una orden y descuenta el stock EN TRANSACCIÓN:
  /// si algo falla, el inventario no se descuadra.
  Future<void> usarRepuesto({
    required int ordenId,
    required int repuestoId,
    required int cantidad,
  }) async {
    if (cantidad <= 0) {
      throw const TallerException('La cantidad debe ser mayor que 0');
    }
    await transaction(() async {
      await _exigirOrdenAbierta(ordenId);
      final rep = await (select(repuestos)
            ..where((r) => r.id.equals(repuestoId)))
          .getSingle();
      if (rep.existencias < cantidad) {
        throw TallerException(
          'Stock insuficiente de "${rep.nombre}": '
          'hay ${rep.existencias}, se piden $cantidad',
        );
      }

      await (update(repuestos)..where((r) => r.id.equals(repuestoId))).write(
        RepuestosCompanion(existencias: Value(rep.existencias - cantidad)),
      );

      await into(repuestosUsados).insert(RepuestosUsadosCompanion.insert(
        ordenId: ordenId,
        repuestoId: repuestoId,
        cantidad: cantidad,
        precioUnitario: rep.precioVenta,
      ));

      // El total se calcula en Dart: multiplicar columnas int*real dentro de
      // un SUM de Drift devuelve un tipo int y puede fallar al leer decimales.
      final usados = await (select(repuestosUsados)
            ..where((u) => u.ordenId.equals(ordenId)))
          .get();
      final total =
          usados.fold<double>(0, (a, u) => a + u.cantidad * u.precioUnitario);
      await (update(ordenes)..where((o) => o.id.equals(ordenId)))
          .write(OrdenesCompanion(totalRepuestos: Value(total)));
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 6. PAGOS Y SALDOS
  // ═══════════════════════════════════════════════════════════════

  /// Saldo de una orden = mano de obra + repuestos − pagos.
  Future<double> saldoDeOrden(int ordenId) async {
    final orden = await obtenerOrden(ordenId);
    if (orden == null) return 0;
    final lista = await (select(pagos)..where((p) => p.ordenId.equals(ordenId)))
        .get();
    final pagado = lista.fold<double>(0, (a, p) => a + p.monto);
    return orden.totalManoObra + orden.totalRepuestos - pagado;
  }

  Future<void> registrarPago({
    required int ordenId,
    required double monto,
    String? metodo,
  }) async {
    if (monto <= 0) {
      throw const TallerException('El monto debe ser mayor que 0');
    }
    await transaction(() async {
      final orden = await obtenerOrden(ordenId);
      if (orden == null) {
        throw TallerException('La orden #$ordenId no existe');
      }
      if (EstadoOrden.desdeValor(orden.estado) == EstadoOrden.cancelada) {
        throw const TallerException('No se pueden registrar pagos en una orden cancelada');
      }
      final saldo = await saldoDeOrden(ordenId);
      if (monto > saldo + _tolerancia) {
        throw TallerException(
          'El pago (\$${monto.toStringAsFixed(2)}) supera el saldo '
          'pendiente (\$${saldo.toStringAsFixed(2)})',
        );
      }
      await into(pagos).insert(PagosCompanion.insert(
        ordenId: ordenId,
        fecha: DateTime.now(),
        monto: monto,
        metodo: Value(metodo),
      ));
    });
  }

  /// Órdenes (no canceladas) con saldo > 0, con su cliente y vehículo.
  Stream<List<OrdenConSaldo>> observarOrdenesConSaldo() {
    final query = select(ordenes).join([
      innerJoin(vehiculos, vehiculos.id.equalsExp(ordenes.vehiculoId)),
      innerJoin(clientes, clientes.id.equalsExp(vehiculos.clienteId)),
      leftOuterJoin(pagos, pagos.ordenId.equalsExp(ordenes.id)),
    ])
      ..where(ordenes.estado.equals(EstadoOrden.cancelada.valor).not());

    return query.watch().map((rows) {
      final mapa = <int, OrdenConSaldo>{};
      for (final row in rows) {
        final o = row.readTable(ordenes);
        final p = row.readTableOrNull(pagos);
        final pagado = (mapa[o.id]?.pagado ?? 0) + (p?.monto ?? 0);
        mapa[o.id] = OrdenConSaldo(
          orden: o,
          vehiculo: row.readTable(vehiculos),
          cliente: row.readTable(clientes),
          pagado: pagado,
          saldo: o.totalManoObra + o.totalRepuestos - pagado,
        );
      }
      return mapa.values.where((e) => e.saldo > 0.01).toList();
    });
  }

  /// Deuda total de cada cliente con saldo pendiente (mayor deuda primero).
  Stream<List<SaldoCliente>> observarSaldosPorCliente() {
    return observarOrdenesConSaldo().map((lista) {
      final mapa = <int, SaldoCliente>{};
      for (final e in lista) {
        final previo = mapa[e.cliente.id];
        mapa[e.cliente.id] = SaldoCliente(
          cliente: e.cliente,
          pendiente: (previo?.pendiente ?? 0) + e.saldo,
          ordenes: [...?previo?.ordenes, e],
        );
      }
      final resultado = mapa.values.toList()
        ..sort((a, b) => b.pendiente.compareTo(a.pendiente));
      return resultado;
    });
  }

  Stream<double> observarDeudaCliente(int clienteId) {
    return observarOrdenesConSaldo().map((lista) => lista
        .where((e) => e.cliente.id == clienteId)
        .fold<double>(0, (a, e) => a + e.saldo));
  }

  // ═══════════════════════════════════════════════════════════════
  // 7. INVENTARIO
  // ═══════════════════════════════════════════════════════════════

  Stream<List<Repuesto>> observarRepuestosBajos({int umbral = umbralStockBajo}) {
    return (select(repuestos)
          ..where((r) => r.existencias.isSmallerOrEqualValue(umbral))
          ..orderBy([(r) => OrderingTerm.asc(r.existencias)]))
        .watch();
  }

  Stream<List<Repuesto>> observarInventario() {
    return (select(repuestos)..orderBy([(r) => OrderingTerm.asc(r.nombre)]))
        .watch();
  }

  Future<int> insertarRepuesto({
    required String codigo,
    required String nombre,
    required double precioVenta,
    required int existencias,
  }) async {
    final cod = codigo.trim().toUpperCase();
    final repetido = await (select(repuestos)..where((r) => r.codigo.equals(cod)))
        .getSingleOrNull();
    if (repetido != null) {
      throw TallerException('Ya existe un repuesto con el código $cod');
    }
    return into(repuestos).insert(RepuestosCompanion.insert(
      codigo: cod,
      nombre: nombre.trim(),
      precioVenta: precioVenta,
      existencias: Value(existencias),
    ));
  }

  /// Suma [cantidad] unidades al stock de un repuesto (compra/reposición).
  Future<void> reponerStock(int repuestoId, int cantidad) async {
    if (cantidad <= 0) {
      throw const TallerException('La cantidad debe ser mayor que 0');
    }
    await transaction(() async {
      final rep = await (select(repuestos)
            ..where((r) => r.id.equals(repuestoId)))
          .getSingle();
      await (update(repuestos)..where((r) => r.id.equals(repuestoId))).write(
        RepuestosCompanion(existencias: Value(rep.existencias + cantidad)),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 8. FACTURACIÓN EN UN PERÍODO
  // ═══════════════════════════════════════════════════════════════

  /// Resumen del período [desde, hasta] (ambos días inclusive).
  /// - facturado: total (mano de obra + repuestos) de las órdenes no
  ///   canceladas cuya fecha de entrada cae en el período.
  /// - cobrado: suma de los pagos recibidos en el período.
  Future<ResumenPeriodo> resumenPeriodo(DateTime desde, DateTime hasta) async {
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fin = DateTime(hasta.year, hasta.month, hasta.day + 1);

    final ordenesPeriodo = await (select(ordenes)
          ..where((o) =>
              o.fechaEntrada.isBiggerOrEqualValue(inicio) &
              o.fechaEntrada.isSmallerThanValue(fin) &
              o.estado.equals(EstadoOrden.cancelada.valor).not()))
        .get();
    final facturado = ordenesPeriodo.fold<double>(
      0,
      (a, o) => a + o.totalManoObra + o.totalRepuestos,
    );

    final pagosPeriodo = await (select(pagos)
          ..where((p) =>
              p.fecha.isBiggerOrEqualValue(inicio) &
              p.fecha.isSmallerThanValue(fin)))
        .get();
    final cobrado = pagosPeriodo.fold<double>(0, (a, p) => a + p.monto);

    return ResumenPeriodo(
      facturado: facturado,
      cobrado: cobrado,
      ordenes: ordenesPeriodo.length,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Clases auxiliares (no son tablas, son "vistas" para la UI)
// ═══════════════════════════════════════════════════════════════

class OrdenDetalle {
  final Orden orden;
  final Vehiculo vehiculo;
  final Cliente cliente;
  final Mecanico? mecanico;
  const OrdenDetalle({
    required this.orden,
    required this.vehiculo,
    required this.cliente,
    this.mecanico,
  });

  EstadoOrden get estado => EstadoOrden.desdeValor(orden.estado);
  double get total => orden.totalManoObra + orden.totalRepuestos;
}

class MecanicoConCarga {
  final Mecanico mecanico;
  final List<Orden> ordenes;
  const MecanicoConCarga({required this.mecanico, required this.ordenes});

  int get abiertas => ordenes.length;
}

class OrdenConSaldo {
  final Orden orden;
  final Vehiculo vehiculo;
  final Cliente cliente;
  final double pagado;
  final double saldo;
  const OrdenConSaldo({
    required this.orden,
    required this.vehiculo,
    required this.cliente,
    required this.pagado,
    required this.saldo,
  });
}

class SaldoCliente {
  final Cliente cliente;
  final double pendiente;
  final List<OrdenConSaldo> ordenes;
  const SaldoCliente({
    required this.cliente,
    required this.pendiente,
    required this.ordenes,
  });
}

class VehiculoConCliente {
  final Vehiculo vehiculo;
  final Cliente cliente;
  const VehiculoConCliente({required this.vehiculo, required this.cliente});
}

class RepuestoUsadoDetalle {
  final RepuestoUsado uso;
  final Repuesto repuesto;
  const RepuestoUsadoDetalle({required this.uso, required this.repuesto});

  double get subtotal => uso.cantidad * uso.precioUnitario;
}

class ResumenPeriodo {
  final double facturado;
  final double cobrado;
  final int ordenes;
  const ResumenPeriodo({
    required this.facturado,
    required this.cobrado,
    required this.ordenes,
  });
}

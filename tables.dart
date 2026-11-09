import 'package:drift/drift.dart';

// Nota: se fija el nombre de cada clase de datos con @DataClassName para que
// el código generado por Drift sea predecible (p. ej. RepuestoUsado).

// 1. Clientes
@DataClassName('Cliente')
class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 80)();
  TextColumn get telefono => text().withLength(min: 1, max: 20)();
  TextColumn get direccion => text().nullable()();
}

// 2. Vehículos
@DataClassName('Vehiculo')
class Vehiculos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId =>
      integer().references(Clientes, #id, onDelete: KeyAction.cascade)();
  TextColumn get matricula => text().withLength(min: 1, max: 15).unique()();
  TextColumn get marca => text()();
  TextColumn get modelo => text()();
  IntColumn get anio => integer()();
  IntColumn get kilometraje => integer().withDefault(const Constant(0))();
}

// 3. Mecánicos
@DataClassName('Mecanico')
class Mecanicos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 80)();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

// 4. Repuestos (Inventario)
@DataClassName('Repuesto')
class Repuestos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get codigo => text().unique()();
  TextColumn get nombre => text()();
  RealColumn get precioVenta => real()();
  IntColumn get existencias => integer().withDefault(const Constant(0))();
}

// 5. Órdenes
@DataClassName('Orden')
class Ordenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehiculoId =>
      integer().references(Vehiculos, #id, onDelete: KeyAction.cascade)();
  IntColumn get mecanicoId =>
      integer().nullable().references(Mecanicos, #id)();
  DateTimeColumn get fechaEntrada => dateTime()();
  DateTimeColumn get fechaSalida => dateTime().nullable()();
  TextColumn get problemaReportado => text()();
  TextColumn get estado => text().withDefault(const Constant('recibida'))();
  RealColumn get totalManoObra => real().withDefault(const Constant(0))();
  RealColumn get totalRepuestos => real().withDefault(const Constant(0))();
}

// 6. Trabajos (Mano de obra)
@DataClassName('Trabajo')
class Trabajos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId =>
      integer().references(Ordenes, #id, onDelete: KeyAction.cascade)();
  TextColumn get descripcion => text()();
  RealColumn get precio => real()();
}

// 7. Repuestos Usados en una orden
@DataClassName('RepuestoUsado')
class RepuestosUsados extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId =>
      integer().references(Ordenes, #id, onDelete: KeyAction.cascade)();
  IntColumn get repuestoId =>
      integer().references(Repuestos, #id, onDelete: KeyAction.restrict)();
  IntColumn get cantidad => integer()();
  RealColumn get precioUnitario => real()();
}

// 8. Pagos
@DataClassName('Pago')
class Pagos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId =>
      integer().references(Ordenes, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get fecha => dateTime()();
  RealColumn get monto => real()();
  TextColumn get metodo => text().nullable()();
}
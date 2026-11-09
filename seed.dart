import 'package:drift/drift.dart' show Value;

import 'app_database.dart';

/// Carga los datos de referencia (mecánicos e inventario inicial) solo si las
/// tablas están vacías. Es idempotente.
Future<void> seedIfEmpty(AppDatabase db) async {
  final hayMecanicos = (await db.select(db.mecanicos).get()).isNotEmpty;
  if (!hayMecanicos) {
    await db.batch((b) {
      b.insertAll(db.mecanicos, [
        MecanicosCompanion.insert(nombre: 'Carlos'),
        MecanicosCompanion.insert(nombre: 'Luis'),
      ]);
    });
  }

  final hayRepuestos = (await db.select(db.repuestos).get()).isNotEmpty;
  if (!hayRepuestos) {
    await db.batch((b) {
      b.insertAll(db.repuestos, [
        RepuestosCompanion.insert(
            codigo: 'REP-001',
            nombre: 'Filtro de aceite',
            precioVenta: 15.50,
            existencias: const Value(20)),
        RepuestosCompanion.insert(
            codigo: 'REP-002',
            nombre: 'Pastillas de freno',
            precioVenta: 45.00,
            existencias: const Value(4)),
        RepuestosCompanion.insert(
            codigo: 'REP-003',
            nombre: 'Bujía',
            precioVenta: 8.00,
            existencias: const Value(50)),
        RepuestosCompanion.insert(
            codigo: 'REP-004',
            nombre: 'Correa de distribución',
            precioVenta: 120.00,
            existencias: const Value(2)),
        RepuestosCompanion.insert(
            codigo: 'REP-005',
            nombre: 'Aceite 10W-40 (litro)',
            precioVenta: 12.00,
            existencias: const Value(30)),
      ]);
    });
  }
}

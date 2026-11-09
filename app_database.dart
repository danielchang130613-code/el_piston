import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/ordenes_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Clientes,
    Vehiculos,
    Mecanicos,
    Ordenes,
    Trabajos,
    Repuestos,
    RepuestosUsados,
    Pagos,
  ],
  daos: [OrdenesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'el_piston_db'));

  /// Constructor para tests con base de datos en memoria.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/daos/ordenes_dao.dart';
import '../data/estado_orden.dart';

/// Estado de la pantalla de órdenes abiertas (lista, filtro y total por cobrar).
class OrdenesViewModel extends ChangeNotifier {
  final OrdenesDao _dao;
  StreamSubscription<List<OrdenDetalle>>? _sub;
  StreamSubscription<List<OrdenConSaldo>>? _subSaldos;

  List<OrdenDetalle> _ordenes = [];
  List<OrdenConSaldo> _conSaldo = [];
  EstadoOrden? _filtro;
  bool _cargando = true;
  String? _error;

  OrdenesViewModel(this._dao) {
    _sub = _dao.observarAbiertasDetalle().listen((data) {
      _ordenes = data;
      _cargando = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _cargando = false;
      _error = 'No se pudieron cargar las órdenes';
      debugPrint('Error observando órdenes: $e');
      notifyListeners();
    });

    _subSaldos = _dao.observarOrdenesConSaldo().listen((data) {
      _conSaldo = data;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Error observando saldos: $e');
    });
  }

  bool get cargando => _cargando;
  String? get error => _error;
  EstadoOrden? get filtro => _filtro;

  /// Órdenes abiertas, filtradas por estado si hay un filtro activo.
  List<OrdenDetalle> get ordenes => _filtro == null
      ? _ordenes
      : _ordenes.where((o) => o.estado == _filtro).toList();

  int cantidadEn(EstadoOrden estado) =>
      _ordenes.where((o) => o.estado == estado).length;

  int get totalAbiertas => _ordenes.length;

  double get totalPorCobrar =>
      _conSaldo.fold<double>(0, (a, e) => a + e.saldo);

  void filtrarPor(EstadoOrden? estado) {
    _filtro = estado;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subSaldos?.cancel();
    super.dispose();
  }
}

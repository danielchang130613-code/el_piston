/// Error de regla de negocio con un mensaje apto para mostrar al usuario
/// (stock insuficiente, pago mayor al saldo, orden cerrada, etc.).
class TallerException implements Exception {
  final String mensaje;
  const TallerException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Estados posibles de una orden de servicio.
///
/// En la base de datos se guarda [valor] (texto), por lo que las órdenes ya
/// existentes siguen siendo compatibles.
enum EstadoOrden {
  recibida('recibida', 'Recibida'),
  enDiagnostico('en diagnóstico', 'En diagnóstico'),
  enReparacion('en reparación', 'En reparación'),
  listaParaEntregar('lista para entregar', 'Lista para entregar'),
  entregada('entregada', 'Entregada'),
  cancelada('cancelada', 'Cancelada');

  /// Texto almacenado en la BD.
  final String valor;

  /// Texto mostrado al usuario.
  final String etiqueta;

  const EstadoOrden(this.valor, this.etiqueta);

  /// Una orden entregada o cancelada ya no admite cambios.
  bool get esFinal => this == entregada || this == cancelada;

  /// Valores (texto) de los estados que cierran una orden.
  static List<String> get valoresFinales =>
      [entregada.valor, cancelada.valor];

  static EstadoOrden desdeValor(String valor) => values.firstWhere(
        (e) => e.valor == valor,
        orElse: () => recibida,
      );
}

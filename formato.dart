/// Utilidades de formato compartidas por todas las vistas.

String dinero(double valor) => '\$${valor.toStringAsFixed(2)}';

String _dos(int n) => n.toString().padLeft(2, '0');

String fecha(DateTime d) => '${_dos(d.day)}/${_dos(d.month)}/${d.year}';

String fechaHora(DateTime d) => '${fecha(d)} ${_dos(d.hour)}:${_dos(d.minute)}';

/// Convierte texto a número aceptando coma o punto decimal ("12,50" o "12.50").
double? parseDecimal(String? texto) {
  if (texto == null) return null;
  return double.tryParse(texto.trim().replaceAll(',', '.'));
}

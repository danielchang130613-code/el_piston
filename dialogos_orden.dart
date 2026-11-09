import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../data/app_database.dart';

/// Resultado del diálogo de pago.
class PagoInput {
  final double monto;
  final String metodo;
  const PagoInput(this.monto, this.metodo);
}

/// Resultado del diálogo de trabajo.
class TrabajoInput {
  final String descripcion;
  final double precio;
  const TrabajoInput(this.descripcion, this.precio);
}

/// Resultado del diálogo de repuesto.
class RepuestoInput {
  final Repuesto repuesto;
  final int cantidad;
  const RepuestoInput(this.repuesto, this.cantidad);
}

/// Los diálogos son StatefulWidget propios para que los controladores se
/// liberen correctamente al cerrarse.
class DialogoPago extends StatefulWidget {
  final double saldo;
  const DialogoPago({super.key, required this.saldo});

  @override
  State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _monto =
      TextEditingController(text: widget.saldo.toStringAsFixed(2));
  String _metodo = 'Efectivo';

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pago'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Saldo pendiente: ${dinero(widget.saldo)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _monto,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto'),
                validator: (v) {
                  final n = parseDecimal(v);
                  if (n == null || n <= 0) return 'Monto inválido';
                  if (n > widget.saldo + 0.005) {
                    return 'No puede superar el saldo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _metodo,
                decoration: const InputDecoration(labelText: 'Método'),
                items: const ['Efectivo', 'Transferencia', 'Tarjeta']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => _metodo = v ?? _metodo,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                  context, PagoInput(parseDecimal(_monto.text)!, _metodo));
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class DialogoTrabajo extends StatefulWidget {
  const DialogoTrabajo({super.key});

  @override
  State<DialogoTrabajo> createState() => _DialogoTrabajoState();
}

class _DialogoTrabajoState extends State<DialogoTrabajo> {
  final _form = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _precio = TextEditingController();

  @override
  void dispose() {
    _desc.dispose();
    _precio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo trabajo'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _desc,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej.: Cambio de aceite',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precio,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Precio mano de obra'),
                validator: (v) {
                  final n = parseDecimal(v);
                  return (n == null || n <= 0) ? 'Precio inválido' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                TrabajoInput(_desc.text.trim(), parseDecimal(_precio.text)!),
              );
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class DialogoRepuesto extends StatefulWidget {
  final List<Repuesto> repuestos;
  const DialogoRepuesto({super.key, required this.repuestos});

  @override
  State<DialogoRepuesto> createState() => _DialogoRepuestoState();
}

class _DialogoRepuestoState extends State<DialogoRepuesto> {
  final _form = GlobalKey<FormState>();
  final _cantidad = TextEditingController(text: '1');
  late Repuesto _seleccionado = widget.repuestos.first;

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Usar repuesto'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Repuesto>(
                initialValue: _seleccionado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Repuesto'),
                items: widget.repuestos
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            '${r.nombre} (${r.existencias} uds · ${dinero(r.precioVenta)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  if (v != null) _seleccionado = v;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cantidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Cantidad inválida';
                  if (n > _seleccionado.existencias) {
                    return 'Solo hay ${_seleccionado.existencias} en stock';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                RepuestoInput(_seleccionado, int.parse(_cantidad.text.trim())),
              );
            }
          },
          child: const Text('Usar'),
        ),
      ],
    );
  }
}

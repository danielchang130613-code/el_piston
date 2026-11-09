import 'package:flutter/material.dart';

import '../../core/formato.dart';

class RepuestoNuevoInput {
  final String codigo;
  final String nombre;
  final double precio;
  final int existencias;
  const RepuestoNuevoInput(this.codigo, this.nombre, this.precio, this.existencias);
}

class DialogoRepuestoNuevo extends StatefulWidget {
  const DialogoRepuestoNuevo({super.key});

  @override
  State<DialogoRepuestoNuevo> createState() => _DialogoRepuestoNuevoState();
}

class _DialogoRepuestoNuevoState extends State<DialogoRepuestoNuevo> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _existencias = TextEditingController(text: '0');

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _precio.dispose();
    _existencias.dispose();
    super.dispose();
  }

  String? _requerido(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo repuesto'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codigo,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Código'),
                validator: _requerido,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _requerido,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precio,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio de venta'),
                validator: (v) {
                  final n = parseDecimal(v);
                  return (n == null || n < 0) ? 'Precio inválido' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _existencias,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Existencias iniciales'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n < 0) ? 'Cantidad inválida' : null;
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
                RepuestoNuevoInput(
                  _codigo.text.trim(),
                  _nombre.text.trim(),
                  parseDecimal(_precio.text)!,
                  int.parse(_existencias.text.trim()),
                ),
              );
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class DialogoReponer extends StatefulWidget {
  final String nombre;
  const DialogoReponer({super.key, required this.nombre});

  @override
  State<DialogoReponer> createState() => _DialogoReponerState();
}

class _DialogoReponerState extends State<DialogoReponer> {
  final _form = GlobalKey<FormState>();
  final _cantidad = TextEditingController();

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reponer: ${widget.nombre}'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _cantidad,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Unidades que llegaron'),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            return (n == null || n <= 0) ? 'Cantidad inválida' : null;
          },
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
              Navigator.pop(context, int.parse(_cantidad.text.trim()));
            }
          },
          child: const Text('Reponer'),
        ),
      ],
    );
  }
}

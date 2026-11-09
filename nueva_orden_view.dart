import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../data/daos/ordenes_dao.dart';
import '../../data/taller_exception.dart';

class NuevaOrdenView extends StatefulWidget {
  const NuevaOrdenView({super.key});

  @override
  State<NuevaOrdenView> createState() => _NuevaOrdenViewState();
}

class _NuevaOrdenViewState extends State<NuevaOrdenView> {
  final _formKey = GlobalKey<FormState>();
  late final OrdenesDao _dao;
  late final Stream<List<Mecanico>> _mecanicos;

  // Cliente
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  // Vehículo
  final _matriculaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _kmCtrl = TextEditingController(text: '0');

  // Orden
  final _problemaCtrl = TextEditingController();
  int? _mecanicoId;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _dao = context.read<AppDatabase>().ordenesDao;
    _mecanicos = _dao.observarMecanicos();
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _telefonoCtrl,
      _direccionCtrl,
      _matriculaCtrl,
      _marcaCtrl,
      _modeloCtrl,
      _anioCtrl,
      _kmCtrl,
      _problemaCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Al salir del teléfono, si el cliente ya existe se rellenan sus datos.
  Future<void> _autocompletarCliente() async {
    final tel = _telefonoCtrl.text.trim();
    if (tel.isEmpty) return;
    final c = await _dao.buscarClientePorTelefono(tel);
    if (c == null || !mounted) return;
    if (_nombreCtrl.text.trim().isEmpty) _nombreCtrl.text = c.nombre;
    if (_direccionCtrl.text.trim().isEmpty && c.direccion != null) {
      _direccionCtrl.text = c.direccion!;
    }
  }

  /// Al salir de la matrícula, si el vehículo ya existe se rellenan sus datos.
  Future<void> _autocompletarVehiculo() async {
    final placa = _matriculaCtrl.text.trim();
    if (placa.isEmpty) return;
    final v = await _dao.buscarVehiculoPorMatricula(placa);
    if (v == null || !mounted) return;
    _marcaCtrl.text = v.marca;
    _modeloCtrl.text = v.modelo;
    _anioCtrl.text = '${v.anio}';
    _kmCtrl.text = '${v.kilometraje}';
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await _dao.registrarIngreso(
        nombre: _nombreCtrl.text,
        telefono: _telefonoCtrl.text,
        direccion: _direccionCtrl.text,
        matricula: _matriculaCtrl.text,
        marca: _marcaCtrl.text,
        modelo: _modeloCtrl.text,
        anio: int.parse(_anioCtrl.text.trim()),
        kilometraje: int.parse(_kmCtrl.text.trim()),
        problema: _problemaCtrl.text,
        mecanicoId: _mecanicoId,
      );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Orden creada correctamente')),
      );
    } on TallerException catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  String? _requerido(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Seccion('Datos del cliente'),
            Focus(
              onFocusChange: (tieneFoco) {
                if (!tieneFoco) _autocompletarCliente();
              },
              child: TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono *',
                  helperText: 'Si el cliente ya existe, se reutiliza',
                ),
                validator: _requerido,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              validator: _requerido,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionCtrl,
              decoration:
                  const InputDecoration(labelText: 'Dirección (opcional)'),
            ),
            const SizedBox(height: 20),
            const _Seccion('Datos del vehículo'),
            Focus(
              onFocusChange: (tieneFoco) {
                if (!tieneFoco) _autocompletarVehiculo();
              },
              child: TextFormField(
                controller: _matriculaCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Matrícula *',
                  helperText: 'Si el vehículo ya existe, se rellenan sus datos',
                ),
                validator: _requerido,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _marcaCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Marca *'),
              validator: _requerido,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modeloCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Modelo *'),
              validator: _requerido,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anioCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Año *'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Año inválido';
                      if (n < 1900 || n > DateTime.now().year + 1) {
                        return '1900-${DateTime.now().year + 1}';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _kmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kilometraje'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 0) return 'Inválido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _Seccion('Orden de servicio'),
            TextFormField(
              controller: _problemaCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Problema reportado *'),
              validator: _requerido,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Mecanico>>(
              stream: _mecanicos,
              builder: (context, snap) {
                final mecanicos = snap.data ?? const <Mecanico>[];
                return DropdownButtonFormField<int?>(
                  initialValue: _mecanicoId,
                  decoration:
                      const InputDecoration(labelText: 'Mecánico asignado'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sin asignar'),
                    ),
                    ...mecanicos.map(
                      (m) => DropdownMenuItem<int?>(
                        value: m.id,
                        child: Text(m.nombre),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _mecanicoId = v),
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar orden'),
              onPressed: _guardando ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  const _Seccion(this.titulo);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

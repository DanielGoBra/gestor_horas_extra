import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/iconografia.dart';
import '../core/tema.dart';
import '../state/sesion_controller.dart';
import 'widgets/comun.dart';

class VistaLogin extends ConsumerStatefulWidget {
  const VistaLogin({super.key});

  @override
  ConsumerState<VistaLogin> createState() => _VistaLoginState();
}

class _VistaLoginState extends ConsumerState<VistaLogin> {
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _enviando = false;
  bool _verClave = false;

  @override
  void dispose() {
    _codigo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _error = null;
      _enviando = true;
    });
    final error = await ref.read(sesionProvider.notifier).entrar(
          _codigo.text.trim(),
          _password.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
            padding: const EdgeInsets.all(28),
            child: Vidrio(
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, _) {
                  final apilado = MediaQuery.sizeOf(context).width < 760;
                  final marca = Padding(
                    padding: const EdgeInsets.fromLTRB(36, 40, 28, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Paleta.pantone375,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            IconosInk.reloj,
                            size: 32,
                            color: Paleta.pantone300,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Gestor de Horas Extra',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Registro operativo, cálculo automático de recargos y aprobación del jefe de operaciones.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Paleta.tintaSuave,
                              ),
                        ),
                        const SizedBox(height: 28),
                        const _PuntoMarca(
                          icono: IconosInk.sparkle,
                          texto: 'Tramos diurnos, nocturnos y dominicales calculados por el sistema',
                        ),
                        const SizedBox(height: 10),
                        const _PuntoMarca(
                          icono: IconosInk.verificado,
                          texto: 'El jefe de operaciones aprueba o rechaza las horas de las operativas',
                        ),
                        const SizedBox(height: 10),
                        const _PuntoMarca(
                          icono: IconosInk.sinRed,
                          texto: 'Cola local si la red se interrumpe',
                        ),
                      ],
                    ),
                  );
                  final formulario = Padding(
                    padding: const EdgeInsets.fromLTRB(28, 36, 36, 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Iniciar sesión',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Usa tu usuario o el correo de INKLUSIVA',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 22),
                        const EtiquetaCampo('Usuario o correo'),
                        TextField(
                          controller: _codigo,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Paleta.tinta),
                          decoration: const InputDecoration(
                            hintText: 'LUISA o luisa@example.com',
                            prefixIcon: Icon(IconosInk.identificacion),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const EtiquetaCampo('Contraseña'),
                        TextField(
                          controller: _password,
                          obscureText: !_verClave,
                          onSubmitted: (_) => _entrar(),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Paleta.tinta),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(IconosInk.clave),
                            suffixIcon: IconButton(
                              tooltip: _verClave ? 'Ocultar' : 'Mostrar',
                              onPressed: () => setState(() => _verClave = !_verClave),
                              icon: Icon(
                                _verClave
                                    ? IconosInk.ocultar
                                    : IconosInk.ver,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _enviando ? null : _entrar,
                          icon: _enviando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(IconosInk.entrar),
                          label: Text(_enviando ? 'Verificando…' : 'Entrar'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Demo: JEFEOP / ADRIANA / LUISA  ·  clave inklusiva',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Paleta.tintaSuave,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _enviando
                                  ? null
                                  : () {
                                      _codigo.text = 'JEFEOP';
                                      _password.text = 'inklusiva';
                                      _entrar();
                                    },
                              icon: const Icon(IconosInk.bandeja, size: 18),
                              label: const Text('Probar como jefe de operaciones'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _enviando
                                  ? null
                                  : () {
                                      _codigo.text = 'ADRIANA';
                                      _password.text = 'inklusiva';
                                      _entrar();
                                    },
                              icon: const Icon(IconosInk.rh, size: 18),
                              label: const Text('Probar como RH'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _enviando
                                  ? null
                                  : () {
                                      _codigo.text = 'LUISA';
                                      _password.text = 'inklusiva';
                                      _entrar();
                                    },
                              icon: const Icon(IconosInk.operativo, size: 18),
                              label: const Text('Probar como operativo'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  if (apilado) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [marca, formulario],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: marca),
                        Container(width: 1, color: Colors.white.withValues(alpha: 0.35)),
                        Expanded(flex: 4, child: formulario),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _PuntoMarca extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _PuntoMarca({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: Paleta.pantone300),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Paleta.tinta),
          ),
        ),
      ],
    );
  }
}

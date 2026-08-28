import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/http/cliente_http.dart';
import '../data/local/cola_outbox.dart';
import '../data/repositorios/repositorios_remoto.dart';
import '../domain/contratos.dart';
import 'enviar_solicitud.dart';

final clienteHttpProvider = Provider<ClienteHttp>((ref) => ClienteHttp());

final authRepoProvider = Provider<RepositorioAuth>(
  (ref) => RepositorioAuthApi(ref.watch(clienteHttpProvider)),
);

final horasRepoProvider = Provider<RepositorioHoras>(
  (ref) => RepositorioHorasApi(ref.watch(clienteHttpProvider)),
);

final rhRepoProvider = Provider<RepositorioRh>(
  (ref) => RepositorioRhApi(ref.watch(clienteHttpProvider)),
);

final catalogoRepoProvider = Provider<RepositorioCatalogo>(
  (ref) => RepositorioCatalogoApi(ref.watch(clienteHttpProvider)),
);

final colaLocalProvider = Provider<ColaLocal>((ref) => ColaOutbox());

final enviarSolicitudProvider = Provider(
  (ref) => EnviarSolicitud(ref.watch(horasRepoProvider), ref.watch(colaLocalProvider)),
);

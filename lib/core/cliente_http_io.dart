// O QUE É ESTE ARQUIVO
// Versão do cliente HTTP para celular e desktop (Android, iOS, Linux, Windows, macOS).
// Escolhida por core/cliente_http.dart. Aqui o cookie de sessão é guardado à mão pelo
// ApiClient, então basta o cliente padrão do pacote `http`.

import 'package:http/http.dart' as http;

/// Cria o cliente HTTP padrão (sem tratamento especial de cookie).
http.Client criarClienteHttp() => http.Client();

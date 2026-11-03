// O QUE É ESTE ARQUIVO
// Versão do cliente HTTP para o navegador (Flutter web). Escolhida por core/cliente_http.dart.
// Navegador não deixa o código ler nem escrever o cookie `sid` (é "httpOnly" e o cabeçalho
// Cookie é proibido). Em vez disso, o próprio navegador guarda e reenvia o cookie, desde que
// a requisição seja marcada com `withCredentials = true` ("pode mandar cookies").

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Cria um cliente que deixa o navegador enviar/receber cookies do backend.
http.Client criarClienteHttp() => BrowserClient()..withCredentials = true;

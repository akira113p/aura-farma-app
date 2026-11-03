// O QUE É ESTE ARQUIVO
// Escolhe QUAL cliente HTTP usar conforme onde o app roda: no celular/desktop usa o cliente
// comum (cliente_http_io.dart); no navegador (Flutter web) usa o cliente do navegador, que
// precisa mandar/receber o cookie de sessão automaticamente (cliente_http_web.dart).
// O `export ... if (...)` abaixo é um "import condicional": o Dart escolhe o arquivo certo
// na hora de compilar. Quem usa: core/api_client.dart.
export 'cliente_http_io.dart'
    if (dart.library.js_interop) 'cliente_http_web.dart';

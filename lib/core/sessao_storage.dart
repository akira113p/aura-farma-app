// O QUE É ESTE ARQUIVO
// Onde o cookie de sessão (`sid=...`) fica guardado entre aberturas do app, para o usuário
// não precisar logar toda vez. Quem usa: core/api_client.dart. Tem uma versão real (cofre
// seguro do sistema) e uma versão em memória para testes. Veja GUIA_FLUTTER.md → Cookie de sessão.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o cookie de sessão (`sid=...`). Abstrato para poder trocar em testes.
///
/// `abstract class` é um "contrato": diz QUAIS operações existem (ler, salvar, apagar), sem
/// dizer COMO. Assim o app usa a versão segura e os testes usam uma versão em memória.
abstract class SessaoStorage {
  /// Devolve o cookie guardado, ou null se não houver.
  Future<String?> ler();
  /// Guarda o cookie (substitui o anterior).
  Future<void> salvar(String cookie);
  /// Remove o cookie guardado.
  Future<void> apagar();
}

/// Implementação real: armazenamento seguro do sistema.
///
/// Usa o cofre do sistema (Keychain no iOS, Keystore no Android) via flutter_secure_storage,
/// porque o cookie é como uma senha: quem tiver ele entra na conta.
class SessaoStorageSegura implements SessaoStorage {
  /// Nome sob o qual o cookie fica no cofre.
  static const _chave = 'aurafarma.sid';
  /// Acesso ao cofre do sistema.
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  @override
  /// Lê o cookie do cofre. Se o cofre falhar, devolve null (como se estivesse deslogado).
  Future<String?> ler() async {
    try {
      // `await` aqui dentro do try garante que erros do cofre sejam capturados pelo catch.
      return await _s.read(key: _chave);
    } catch (_) {
      return null;
    }
  }

  @override
  /// Grava o cookie no cofre; falhas são ignoradas (o login vale só nesta execução).
  Future<void> salvar(String cookie) async {
    try {
      await _s.write(key: _chave, value: cookie);
    } catch (_) {}
  }

  @override
  /// Apaga o cookie do cofre; falhas são ignoradas.
  Future<void> apagar() async {
    try {
      await _s.delete(key: _chave);
    } catch (_) {}
  }
}

/// Implementação em memória (testes).
///
/// Guarda tudo numa variável: some quando o programa fecha. Perfeita para testes.
class SessaoStorageMemoria implements SessaoStorage {
  /// O cookie guardado (nulo = nada guardado).
  String? valor;

  @override
  /// Mesmas operações do contrato, mas só mexendo na variável `valor`.
  Future<String?> ler() async => valor;

  @override
  Future<void> salvar(String cookie) async => valor = cookie;

  @override
  Future<void> apagar() async => valor = null;
}

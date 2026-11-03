import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o cookie de sessão (`sid=...`). Abstrato para poder trocar em testes.
abstract class SessaoStorage {
  Future<String?> ler();
  Future<void> salvar(String cookie);
  Future<void> apagar();
}

/// Implementação real: armazenamento seguro do sistema.
class SessaoStorageSegura implements SessaoStorage {
  static const _chave = 'aurafarma.sid';
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  @override
  Future<String?> ler() async {
    try {
      return await _s.read(key: _chave);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> salvar(String cookie) async {
    try {
      await _s.write(key: _chave, value: cookie);
    } catch (_) {}
  }

  @override
  Future<void> apagar() async {
    try {
      await _s.delete(key: _chave);
    } catch (_) {}
  }
}

/// Implementação em memória (testes).
class SessaoStorageMemoria implements SessaoStorage {
  String? valor;

  @override
  Future<String?> ler() async => valor;

  @override
  Future<void> salvar(String cookie) async => valor = cookie;

  @override
  Future<void> apagar() async => valor = null;
}

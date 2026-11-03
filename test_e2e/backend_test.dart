// Teste ponta a ponta contra o backend REAL do auraFarma (não roda no `flutter test` normal).
//
// Pré-requisito: backend de pé (`npm --prefix backend run dev` no prototipo).
// Rodar:  flutter test test_e2e
// Outra URL: flutter test test_e2e --dart-define=API_BASE_URL=http://192.168.0.10:4000/api
//
// Cria uma conta descartável a cada execução (usuário/senha aleatórios, nada fica salvo),
// e exercita o mesmo AppStore que as telas usam: login, seed, solicitados, contagem, logout.

import 'dart:convert';
import 'dart:math';

import 'package:aurafarma_app/core/api_client.dart';
import 'package:aurafarma_app/core/sessao_storage.dart';
import 'package:aurafarma_app/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _base = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://localhost:4000/api');

void main() {
  final rnd = Random.secure();
  final sufixo = List.generate(8, (_) => rnd.nextInt(36).toRadixString(36)).join();
  final usuario = 'e2e_$sufixo';
  final senha = 'Teste-${List.generate(12, (_) => rnd.nextInt(36).toRadixString(36)).join()}1!';

  late AppStore store;
  late SessaoStorageMemoria storage;

  setUpAll(() async {
    // Conta descartável via API pública de cadastro.
    final r = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': usuario,
        'pharmacyName': 'Farmácia E2E',
        'email': '$usuario@teste.local',
        'password': senha,
      }),
    );
    expect(r.statusCode, 201, reason: 'cadastro falhou: ${r.body}');
    storage = SessaoStorageMemoria();
    store = AppStore(api: ApiClient(storage: storage, baseUrl: _base));
  });

  test('login guarda o cookie sid e carrega o estado', () async {
    await store.entrar(usuario, senha);
    expect(store.status, StatusAuth.logado);
    expect(store.usuario?.username, usuario);
    expect(storage.valor, startsWith('sid='));
    expect(store.erroEstado, isNull);
    expect(store.estado.populado, isFalse);
  });

  test('senha errada vira ApiException 401 com a mensagem do backend', () async {
    final outro = AppStore(
        api: ApiClient(storage: SessaoStorageMemoria(), baseUrl: _base));
    await expectLater(
      outro.entrar(usuario, 'errada-123!'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 401)
          .having((e) => e.message, 'message', 'Credenciais inválidas')),
    );
  });

  test('popular exemplo traz produtos com código e categoria', () async {
    await store.popularExemplo();
    expect(store.estado.populado, isTrue);
    expect(store.estado.produtos, isNotEmpty);
    final p = store.estado.produtos.first;
    expect(p.id, isNotEmpty);
    expect(p.codigo, isNotEmpty);
    // scanner: acha pelo código exato
    expect(store.buscarPorCodigo(' ${p.codigo} ')?.id, p.id);
  });

  test('solicitados: registrar, somar +1 e remover', () async {
    final antes = store.estado.solicitacoes.length;
    await store.registrarSolicitacao('Pomada E2E $sufixo', 'cliente pediu');
    expect(store.estado.solicitacoes.length, antes + 1);
    final s = store.estado.solicitacoes.firstWhere((x) => x.nome.startsWith('Pomada E2E'));
    expect(s.pedidos, 1);

    await store.somarSolicitacao(s);
    final s2 = store.estado.solicitacoes.firstWhere((x) => x.id == s.id);
    expect(s2.pedidos, 2);

    await store.removerSolicitacao(s.id);
    expect(store.estado.solicitacoes.any((x) => x.id == s.id), isFalse);
  });

  test('contagem aplica o novo estoque e registra no histórico', () async {
    final p = store.estado.produtos.first;
    final novo = p.quantidade + 3;
    final contagensAntes = store.estado.contagens.length;

    await store.aplicarContagem({p.id: novo});

    expect(store.estado.produtos.firstWhere((x) => x.id == p.id).quantidade, novo);
    expect(store.estado.contagens.length, contagensAntes + 1);
    expect(store.estado.contagens.first.diferencaTotal, 3);

    // O servidor concorda (mesmo dado que o web vê).
    await store.recarregar();
    expect(store.estado.produtos.firstWhere((x) => x.id == p.id).quantidade, novo);
  });

  test('IA: /ia/config responde', () async {
    final r = await store.api.get('/ia/config');
    expect(r['enabled'], isA<bool>());
  });

  test('logout apaga o cookie e a sessão deixa de valer', () async {
    final cookieAntigo = storage.valor!;
    await store.sair();
    expect(store.status, StatusAuth.deslogado);
    expect(storage.valor, isNull);

    // O cookie antigo não serve mais no servidor.
    final r = await http.get(Uri.parse('$_base/auth/me'),
        headers: {'Cookie': cookieAntigo});
    expect(r.statusCode, 401);
  });
}

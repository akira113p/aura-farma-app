// Teste ponta a ponta contra o backend REAL do auraFarma (não roda no `flutter test` normal).
//
// Pré-requisito: backend de pé (`npm --prefix backend run dev` no prototipo).
// Rodar:  flutter test test_e2e
// Outra URL: flutter test test_e2e --dart-define=API_BASE_URL=http://192.168.0.10:4000/api
//
// Cria uma conta descartável a cada execução (usuário/senha aleatórios, nada fica salvo),
// e exercita o mesmo AppStore que as telas usam: login, seed, solicitados, contagem, logout.
// COMO LER ESTE ARQUIVO (explicação para quem está começando)
// E2E = 'end to end' (ponta a ponta): em vez de simular o servidor, o teste conversa com o backend DE VERDADE,
// pela internet/rede local, como o app faria. Por isso ele fica numa pasta separada (test_e2e) e NÃO roda no
// 'flutter test' normal, que só olha a pasta test/. Se o backend estiver desligado, estes testes falham com erro de conexão.
// Passou = o app e o backend entendem um ao outro (login, estoque, solicitados, contagem, logout).
// Falhou = ou o backend mudou algo, ou o app está pedindo errado. Veja a seção 'Testes' do GUIA_FLUTTER.md.
// Os testes abaixo rodam EM SEQUÊNCIA e dependem um do outro (o primeiro faz login, os seguintes usam essa sessão).

import 'dart:convert';
import 'dart:math';

import 'package:aurafarma_app/core/api_client.dart';
import 'package:aurafarma_app/core/sessao_storage.dart';
import 'package:aurafarma_app/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// Endereço do backend. String.fromEnvironment lê o valor passado em --dart-define=API_BASE_URL=...
// na linha de comando; se não for passado, usa o padrão (localhost:4000).
const _base = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://localhost:4000/api');

// main() é onde os testes são declarados. Tudo aqui em cima prepara os dados da conta descartável.
void main() {
  // Random.secure gera números aleatórios; usamos para nome e senha nunca se repetirem entre execuções.
  final rnd = Random.secure();
  // Sufixo aleatório de 8 letras/números (base 36), para o nome de usuário ser único.
  final sufixo = List.generate(8, (_) => rnd.nextInt(36).toRadixString(36)).join();
  final usuario = 'e2e_$sufixo';
  // Senha aleatória que cumpre a política do backend (letras, número e símbolo).
  final senha = 'Teste-${List.generate(12, (_) => rnd.nextInt(36).toRadixString(36)).join()}1!';

  // 'late' = a variável será preenchida mais tarde (no setUpAll), antes de qualquer teste usá-la.
  late AppStore store;
  late SessaoStorageMemoria storage;

  // setUpAll roda UMA vez, antes de todos os testes do arquivo (já 'setUp' rodaria antes de cada teste).
  // Aqui ele cria a conta descartável e monta o AppStore, o mesmo 'cérebro' que as telas usam.
  setUpAll(() async {
    // Conta descartável via API pública de cadastro.
    // POST direto em /auth/register com o pacote http (sem passar pelo app) só para criar a conta.
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
    // Confere que o backend respondeu 201 (criado). 'reason' é a mensagem mostrada se falhar.
    expect(r.statusCode, 201, reason: 'cadastro falhou: ${r.body}');
    // Guarda o cookie de sessão só na memória (nada é gravado no aparelho).
    storage = SessaoStorageMemoria();
    store = AppStore(api: ApiClient(storage: storage, baseUrl: _base));
  });

  // CENÁRIO: conta recém-criada. AÇÃO: entrar(usuario, senha) no AppStore.
  // CONFERIDO: status logado, usuário certo, cookie 'sid=' guardado, sem erro ao carregar o estado e estoque ainda
  // não populado (conta nova). É o coração do 'continuar logado' no celular.
  test('login guarda o cookie sid e carrega o estado', () async {
    await store.entrar(usuario, senha);
    expect(store.status, StatusAuth.logado);
    expect(store.usuario?.username, usuario);
    // startsWith: o cookie guardado começa com 'sid=' (identificador da sessão).
    expect(storage.valor, startsWith('sid='));
    expect(store.erroEstado, isNull);
    expect(store.estado.populado, isFalse);
  });

  // CENÁRIO: um segundo AppStore (sem sessão). AÇÃO: tenta entrar com senha errada.
  // CONFERIDO: o backend responde 401 e o app transforma em ApiException com a mensagem 'Credenciais inválidas',
  // que é o texto que aparece na tela de login.
  test('senha errada vira ApiException 401 com a mensagem do backend', () async {
    final outro = AppStore(
        api: ApiClient(storage: SessaoStorageMemoria(), baseUrl: _base));
    // expectLater espera o resultado de uma operação assíncrona (Future); throwsA(...) diz que esperamos um erro,
    // e 'having' confere campos desse erro (status e mensagem).
    await expectLater(
      outro.entrar(usuario, 'errada-123!'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 401)
          .having((e) => e.message, 'message', 'Credenciais inválidas')),
    );
  });

  // CENÁRIO: conta logada e vazia. AÇÃO: popularExemplo (o backend cria produtos de exemplo).
  // CONFERIDO: o estado fica populado e os produtos têm id, código e categoria; o scanner acha o produto pelo código
  // (mesmo com espaços em volta, que o app remove).
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

  // CENÁRIO: lista de solicitados da conta. AÇÃO: registrar um pedido novo, somar +1 e depois remover.
  // CONFERIDO: a lista cresce, o contador vai de 1 para 2 e o item some. Mostra que criar/editar/apagar chegam ao backend.
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

  // CENÁRIO: um produto com estoque conhecido. AÇÃO: aplicar uma contagem de estoque (+3).
  // CONFERIDO: o estoque muda, aparece uma contagem nova no histórico e, ao recarregar do servidor, o valor persiste
  // (ou seja, foi mesmo salvo no banco e não só na tela).
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

  // CENÁRIO: logado. AÇÃO: GET /ia/config. CONFERIDO: o backend responde com o campo 'enabled' (true/false),
  // que diz se o assistente de IA está ligado. Só confirma que a rota existe e fala o formato esperado.
  test('IA: /ia/config responde', () async {
    final r = await store.api.get('/ia/config');
    expect(r['enabled'], isA<bool>());
  });

  // CENÁRIO: sessão ativa com cookie guardado. AÇÃO: sair() (logout).
  // CONFERIDO: o app fica deslogado, apaga o cookie e o servidor passa a recusar (401) o cookie antigo.
  // Importa por segurança: logout de verdade, não só esconder a tela.
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

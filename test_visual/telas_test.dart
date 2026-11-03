// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renderiza cada tela do app em 412×917 (mesmo tamanho dos frames do Figma) e salva PNGs em
// test_visual/render/, para comparar com design/figma/*.png sem precisar de celular.
//
// Rodar:  flutter test test_visual --update-goldens
// (Sem rede: o ApiClient usa um MockClient.)
// O QUE É ESTE ARQUIVO
// Testes VISUAIS: desenha cada tela do app na memória e tira uma 'foto' (PNG) dela. Servem para gerar as imagens
// do README e comparar com o design do Figma sem precisar de celular. Fica fora de test/, então 'flutter test'
// puro NÃO roda estes; rode com o comando acima.
// Golden = teste de 'foto de referência': 'matchesGoldenFile' compara a tela desenhada com um PNG salvo.
// Com --update-goldens ele não compara, ele GRAVA/atualiza os PNGs em test_visual/render/.
// Precisa de: nada de rede (usa MockClient, um servidor de mentira). Passou = todas as telas desenharam e as fotos foram salvas.
// Falhou = alguma tela deu erro ao desenhar (ou, sem --update-goldens, a imagem mudou). Veja 'Testes' no GUIA_FLUTTER.md.
// Ordem do arquivo: funções auxiliares (_carregarFontes, _store, _montar, _aba, _foto) e depois os testes de cada tela.
//

import 'dart:convert';
import 'dart:io';

import 'package:aurafarma_app/core/api_client.dart';
import 'package:aurafarma_app/core/sessao_storage.dart';
import 'package:aurafarma_app/main.dart';
import 'package:aurafarma_app/scanner.dart';
import 'package:aurafarma_app/state/app_scope.dart';
import 'package:aurafarma_app/state/app_store.dart';
import 'package:aurafarma_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Função auxiliar: carrega as fontes à mão. Em teste o Flutter desenha texto com uma fonte quadrada de erro
// ("blocos"), então carregamos Roboto e os ícones do próprio SDK do Flutter para as fotos ficarem iguais ao app real.
Future<void> _carregarFontes() async {
  // Pasta do SDK do Flutter (variável de ambiente FLUTTER_ROOT, definida pelo comando 'flutter test').
  final raiz = Platform.environment['FLUTTER_ROOT']!;
  // Pasta onde o Flutter guarda as fontes do Material.
  final dir = '$raiz/bin/cache/artifacts/material_fonts';
  // Lê um arquivo de fonte do disco e devolve os bytes no formato que o FontLoader entende.
  Future<ByteData> ler(String f) async =>
      ByteData.sublistView(await File('$dir/$f').readAsBytes());
  // FontLoader registra uma fonte pelo nome: aqui a família Roboto com os 3 estilos (normal, negrito, itálico).
  final roboto = FontLoader('Roboto')
    ..addFont(ler('roboto-regular.ttf'))
    ..addFont(ler('roboto-bold.ttf'))
    ..addFont(ler('roboto-italic.ttf'));
  // load() entrega as fontes ao Flutter. Sem isso o texto sairia como retângulos.
  await roboto.load();
  // Mesma coisa para a fonte dos ícones (MaterialIcons), senão os ícones viram quadradinhos.
  final icones = FontLoader('MaterialIcons')..addFont(ler('materialicons-regular.otf'));
  await icones.load();
}

// Função auxiliar: monta um AppStore (o 'cérebro' do app) já logado e com dados de exemplo fixos,
// para as fotos saírem sempre iguais, sem login nem backend.
AppStore _store() {
  // ApiClient com servidor de mentira (MockClient) que responde sempre {"enabled":true}: nenhuma chamada sai para a internet.
  // SessaoStorageMemoria guarda a sessão só na memória.
  final api = ApiClient(
    client: MockClient((_) async => http.Response('{"enabled":true}', 200)),
    storage: SessaoStorageMemoria(),
    baseUrl: 'http://teste/api',
  );
  // Mini-função para criar um Medicamentos em uma linha (as abreviações são id, nome, código, categoria, quantidade, preço e mínimo).
  Medicamentos m(String id, String n, String sku, String cat, int q, double p, int min) =>
      Medicamentos(id: id, nome: n, codigo: sku, categorias: cat, quantidade: q, preco: p, minimo: min);
  // O '..' (cascata) aplica várias configurações no mesmo objeto: status logado, usuário e o estado com produtos,
  // solicitados e uma contagem. Os dados são de exemplo (6 produtos, alguns com estoque baixo).
  return AppStore(api: api)
    ..status = StatusAuth.logado
    ..usuario = const Usuario(id: 'u1', username: 'ana', pharmacyName: 'Farmácia Ana', email: 'a@a.com')
    ..estado = Estado(
      populado: true,
      produtos: [
        m('1', 'Dipirona 500mg', '7891058001155', 'Analgésico', 42, 8.9, 10),
        m('2', 'Paracetamol 750mg', '7896004703398', 'Analgésico', 7, 12.5, 10),
        m('3', 'Amoxicilina 500mg', '7896422506519', 'Antibiótico', 18, 34.9, 5),
        m('4', 'Loratadina 10mg', '7896714200157', 'Antialérgico', 25, 15.0, 8),
        m('5', 'Omeprazol 20mg', '7896206400866', 'Gastro', 3, 22.4, 6),
        m('6', 'Ibuprofeno 600mg', '7896658003462', 'Anti-inflamatório', 31, 18.75, 10),
      ],
      solicitacoes: const [
        Solicitacao(id: 's1', nome: 'Pomada para queimadura', nota: 'Cliente idosa, recorrente', pedidos: 4, data: '2026-10-30'),
        Solicitacao(id: 's2', nome: 'Melatonina 3mg', nota: '', pedidos: 2, data: '2026-11-01'),
        Solicitacao(id: 's3', nome: 'Protetor solar FPS 70', nota: 'Pediu marca nacional', pedidos: 1, data: '2026-11-02'),
      ],
      contagens: [
        Contagem(id: 'c1', quando: DateTime(2026, 10, 28, 9, 30), ajustes: const [
          AjusteContagem(pid: '1', novoEstoque: 42, diferenca: -2),
          AjusteContagem(pid: '2', novoEstoque: 7, diferenca: 0),
        ]),
      ],
    );
}

// Função auxiliar: desenha o app inteiro (TelaInicial) com o tamanho de tela e o tema pedidos.
// 412x917 é o tamanho dos frames do Figma. 'escuro' liga o tema escuro.
Future<void> _montar(WidgetTester tester, AppStore store,
    {bool escuro = false, Size tamanho = const Size(412, 917)}) async {
  // Define o tamanho da janela de teste em pixels físicos e pixel ratio 1 (1 pixel de tela = 1 pixel de foto).
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  // addTearDown registra uma limpeza que roda ao fim do teste: devolve o tamanho original da tela.
  addTearDown(tester.view.reset);
  // Escolhe tema claro ou escuro antes de desenhar.
  store.tema = escuro ? ThemeMode.dark : ThemeMode.light;
  // Desenha o app dentro de AppScope (que entrega o AppStore às telas) e de um MaterialApp com os dois temas.
  await tester.pumpWidget(AppScope(
    store: store,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaClaro(),
      darkTheme: temaEscuro(),
      themeMode: store.tema,
      home: const TelaInicial(),
    ),
  ));
  // pumpAndSettle: avança o relógio do teste até todas as animações e carregamentos terminarem.
  // Sem isso a foto sairia no meio de uma transição.
  await tester.pumpAndSettle();
}

// Função auxiliar: 'clica' numa aba da barra de baixo pelo texto dela (ex.: 'scanner').
Future<void> _aba(WidgetTester tester, String rotulo) async {
  // tester.tap simula um toque. find.text(rotulo).last pega o ÚLTIMO texto igual na tela (a aba pode aparecer mais de uma vez).
  await tester.tap(find.text(rotulo).last);
  // Espera a animação da troca de aba acabar.
  await tester.pumpAndSettle();
}

// Função auxiliar: tira a 'foto' da tela e compara/grava render/<nome>.png (golden).
// Com --update-goldens grava; sem a flag, falha se a imagem for diferente da salva.
Future<void> _foto(String nome) =>
    expectLater(find.byType(TelaInicial), matchesGoldenFile('render/$nome.png'));

// main() declara os testes. Cada testWidgets abaixo é uma tela (ou um estado de tela) fotografada.
void main() {
  // setUpAll roda uma vez antes de tudo: carrega as fontes.
  setUpAll(_carregarFontes);
  // setUp roda antes de CADA teste: deixa o ambiente igual para todos.
  setUp(() {
    // Celular = toque: sem o anel de foco de teclado que o modo desktop dos testes desenha.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    // 'Bloco de notas' falso do aparelho com um histórico de conversas da IA já salvo (usuário u1),
    // para a tela do assistente aparecer com conteúdo, inclusive uma tabela.
    SharedPreferences.setMockInitialValues({
      'aurafarma.ia.u1': jsonEncode([
        {
          'id': 'h1',
          'titulo': 'Produtos em baixa',
          'atualizadoEm': 1,
          'mensagens': [
            {'role': 'user', 'content': 'Quantos produtos tenho em baixa?'},
            {
              'role': 'assistant',
              'content': 'Você tem **4 produtos** abaixo do mínimo:\n\n'
                  '| Produto | Categoria | Estoque | Mínimo |\n|---|---|---|---|\n'
                  '| Lenço umedecido c/100 | Infantil | 3 | 10 |\n'
                  '| Paracetamol 750mg c/20 | Analgésicos | 8 | 12 |\n'
                  '| Azitromicina 500mg c/5 | Antibióticos | 4 | 6 |\n\n'
                  '- Priorize os antibióticos\n- Revise o **mínimo** dos infantis 🚚',
            },
          ],
        },
        {'id': 'h2', 'titulo': 'Mais vendidos da semana', 'atualizadoEm': 0, 'mensagens': []},
      ]),
    });
  });

  // CENÁRIO: app em tema claro, aba inicial (Estoque). AÇÃO: só desenhar e fotografar. CONFERIDO: a foto salva em render/estoque.png.
  // Nos testes abaixo o formato é o mesmo: 'montar' + (às vezes) mexer na tela + 'foto'. 't' é o tester (controle remoto da tela de teste).
  testWidgets('estoque', (t) async {
    await _montar(t, _store());
    await _foto('estoque');
  });

  // Aba do assistente de IA com a lista de conversas do histórico.
  testWidgets('assistente', (t) async {
    await _montar(t, _store());
    await _aba(t, 'assistente IA');
    await _foto('assistente');
  });

  // Abre a conversa 'Produtos em baixa' (toque no item do histórico) e fotografa a resposta com tabela e negrito.
  testWidgets('assistente conversa (com tabela)', (t) async {
    await _montar(t, _store());
    await _aba(t, 'assistente IA');
    await t.tap(find.text('Produtos em baixa'));
    await t.pumpAndSettle();
    await _foto('assistente_conversa');
  });

  // Aba de contagem de estoque, antes e durante uma sessão de contagem.
  testWidgets('contagem', (t) async {
    await _montar(t, _store());
    await _aba(t, 'contagem');
    await _foto('contagem');
    // Toca em 'começar contagem' para entrar no modo de contagem.
    await t.tap(find.text('começar contagem'));
    await t.pumpAndSettle();
    // enterText digita 40 no segundo campo de texto da tela (índice 1), simulando a pessoa contando o item.
    await t.enterText(find.byType(TextField).at(1), '40');
    await t.pumpAndSettle();
    await _foto('contagem_sessao');
  });

  // Aba de solicitados (produtos que clientes pediram e a loja não tem).
  testWidgets('solicitados', (t) async {
    await _montar(t, _store());
    await _aba(t, 'solicitados');
    await _foto('solicitados');
  });

  // Scanner no computador (sem câmera): o campo de digitar o código é o caminho principal.
  // Computador (sem câmera): o campo de digitação é o caminho principal.
  testWidgets('scanner', (t) async {
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await _foto('scanner');
  });

  // Scanner no celular (com câmera). A câmera de verdade não roda em teste, então a variável scannerTemCameraParaTeste
  // força o app a se comportar como se houvesse câmera (a câmera fica desligada).
  // Celular (com câmera, desligada) — a câmera real não roda em teste.
  testWidgets('scanner celular', (t) async {
    // Liga o 'como se fosse celular'.
    scannerTemCameraParaTeste = true;
    // Ao terminar o teste, desliga (volta a null) para não afetar os outros testes.
    addTearDown(() => scannerTemCameraParaTeste = null);
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await _foto('scanner_celular');
  });

  // Função auxiliar: digita um código de barras no campo do scanner e toca em 'buscar'.
  Future<void> buscarCodigo(WidgetTester t, String codigo) async {
    // find.descendant limita a busca ao campo de texto que está DENTRO da tela do scanner (evita pegar outro campo).
    await t.enterText(
        find.descendant(of: find.byType(TelaScanner), matching: find.byType(TextField)),
        codigo);
    // Toca no botão 'buscar' e espera o resultado aparecer.
    await t.tap(find.text('buscar'));
    await t.pumpAndSettle();
  }

  // Scanner com resultado encontrado (código do Paracetamol, que está com estoque baixo).
  testWidgets('scanner resultado encontrado', (t) async {
    scannerTemCameraParaTeste = true;
    addTearDown(() => scannerTemCameraParaTeste = null);
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await buscarCodigo(t, '7896004703398'); // Paracetamol (estoque baixo)
    await _foto('scanner_resultado');
  });

  // Scanner com código que não existe: mostra a mensagem de produto não cadastrado.
  testWidgets('scanner produto não cadastrado', (t) async {
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await buscarCodigo(t, '0000000000000');
    await _foto('scanner_nao_encontrado');
  });

  // Mesmo tamanho de janela do print do Windows (538x829), tema escuro.
  // Mesma janela do print do Windows (538×829, tema escuro).
  testWidgets('scanner janela windows escuro', (t) async {
    await _montar(t, _store(), escuro: true, tamanho: const Size(538, 829));
    await _aba(t, 'scanner');
    await buscarCodigo(t, '7896422506519');
    await _foto('scanner_windows');
  });

  // Scanner no celular em tema escuro.
  testWidgets('scanner celular escuro', (t) async {
    scannerTemCameraParaTeste = true;
    addTearDown(() => scannerTemCameraParaTeste = null);
    await _montar(t, _store(), escuro: true);
    await _aba(t, 'scanner');
    await buscarCodigo(t, '7891058001155');
    await _foto('scanner_escuro');
  });

  // Estoque em tema escuro.
  testWidgets('estoque escuro', (t) async {
    await _montar(t, _store(), escuro: true);
    await _foto('estoque_escuro');
  });
}

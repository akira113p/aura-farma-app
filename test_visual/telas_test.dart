// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renderiza cada tela do app em 412×917 (mesmo tamanho dos frames do Figma) e salva PNGs em
// test_visual/render/, para comparar com design/figma/*.png sem precisar de celular.
//
// Rodar:  flutter test test_visual --update-goldens
// (Sem rede: o ApiClient usa um MockClient.)

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

Future<void> _carregarFontes() async {
  final raiz = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$raiz/bin/cache/artifacts/material_fonts';
  Future<ByteData> ler(String f) async =>
      ByteData.sublistView(await File('$dir/$f').readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(ler('roboto-regular.ttf'))
    ..addFont(ler('roboto-bold.ttf'))
    ..addFont(ler('roboto-italic.ttf'));
  await roboto.load();
  final icones = FontLoader('MaterialIcons')..addFont(ler('materialicons-regular.otf'));
  await icones.load();
}

AppStore _store() {
  final api = ApiClient(
    client: MockClient((_) async => http.Response('{"enabled":true}', 200)),
    storage: SessaoStorageMemoria(),
    baseUrl: 'http://teste/api',
  );
  Medicamentos m(String id, String n, String sku, String cat, int q, double p, int min) =>
      Medicamentos(id: id, nome: n, codigo: sku, categorias: cat, quantidade: q, preco: p, minimo: min);
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

Future<void> _montar(WidgetTester tester, AppStore store,
    {bool escuro = false, Size tamanho = const Size(412, 917)}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  store.tema = escuro ? ThemeMode.dark : ThemeMode.light;
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
  await tester.pumpAndSettle();
}

Future<void> _aba(WidgetTester tester, String rotulo) async {
  await tester.tap(find.text(rotulo).last);
  await tester.pumpAndSettle();
}

Future<void> _foto(String nome) =>
    expectLater(find.byType(TelaInicial), matchesGoldenFile('render/$nome.png'));

void main() {
  setUpAll(_carregarFontes);
  setUp(() {
    // Celular = toque: sem o anel de foco de teclado que o modo desktop dos testes desenha.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
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

  testWidgets('estoque', (t) async {
    await _montar(t, _store());
    await _foto('estoque');
  });

  testWidgets('assistente', (t) async {
    await _montar(t, _store());
    await _aba(t, 'assistente IA');
    await _foto('assistente');
  });

  testWidgets('assistente conversa (com tabela)', (t) async {
    await _montar(t, _store());
    await _aba(t, 'assistente IA');
    await t.tap(find.text('Produtos em baixa'));
    await t.pumpAndSettle();
    await _foto('assistente_conversa');
  });

  testWidgets('contagem', (t) async {
    await _montar(t, _store());
    await _aba(t, 'contagem');
    await _foto('contagem');
    await t.tap(find.text('começar contagem'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(1), '40');
    await t.pumpAndSettle();
    await _foto('contagem_sessao');
  });

  testWidgets('solicitados', (t) async {
    await _montar(t, _store());
    await _aba(t, 'solicitados');
    await _foto('solicitados');
  });

  // Computador (sem câmera): o campo de digitação é o caminho principal.
  testWidgets('scanner', (t) async {
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await _foto('scanner');
  });

  // Celular (com câmera, desligada) — a câmera real não roda em teste.
  testWidgets('scanner celular', (t) async {
    scannerTemCameraParaTeste = true;
    addTearDown(() => scannerTemCameraParaTeste = null);
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await _foto('scanner_celular');
  });

  Future<void> buscarCodigo(WidgetTester t, String codigo) async {
    await t.enterText(
        find.descendant(of: find.byType(TelaScanner), matching: find.byType(TextField)),
        codigo);
    await t.tap(find.text('buscar'));
    await t.pumpAndSettle();
  }

  testWidgets('scanner resultado encontrado', (t) async {
    scannerTemCameraParaTeste = true;
    addTearDown(() => scannerTemCameraParaTeste = null);
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await buscarCodigo(t, '7896004703398'); // Paracetamol (estoque baixo)
    await _foto('scanner_resultado');
  });

  testWidgets('scanner produto não cadastrado', (t) async {
    await _montar(t, _store());
    await _aba(t, 'scanner');
    await buscarCodigo(t, '0000000000000');
    await _foto('scanner_nao_encontrado');
  });

  // Mesma janela do print do Windows (538×829, tema escuro).
  testWidgets('scanner janela windows escuro', (t) async {
    await _montar(t, _store(), escuro: true, tamanho: const Size(538, 829));
    await _aba(t, 'scanner');
    await buscarCodigo(t, '7896422506519');
    await _foto('scanner_windows');
  });

  testWidgets('scanner celular escuro', (t) async {
    scannerTemCameraParaTeste = true;
    addTearDown(() => scannerTemCameraParaTeste = null);
    await _montar(t, _store(), escuro: true);
    await _aba(t, 'scanner');
    await buscarCodigo(t, '7891058001155');
    await _foto('scanner_escuro');
  });

  testWidgets('estoque escuro', (t) async {
    await _montar(t, _store(), escuro: true);
    await _foto('estoque_escuro');
  });
}

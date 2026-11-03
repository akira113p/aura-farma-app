// O QUE É ESTE ARQUIVO
// Ponto de entrada do app: o Dart começa a executar por aqui (função `main`).
// Aqui ficam também as peças "de cima" da árvore de widgets: MainApp (configura
// tema e estado global), AuthGate (decide entre splash, login e app) e TelaInicial
// (as 5 abas de baixo). Quem usa: o próprio Flutter ao abrir o app.
// Usa: config.dart, login.dart, state/ (AppStore e AppScope), theme/ e as 5 telas.
// Guia para iniciantes: GUIA_FLUTTER.md (na raiz do projeto).

import 'package:flutter/material.dart';
import 'config.dart';
import 'estoque.dart';
import 'scanner.dart';
import 'solicitados.dart';
import 'contagem.dart';
import 'assistente.dart';
import 'login.dart';
import 'state/app_scope.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';
import 'widgets/icones.dart';

// Reexporta os modelos: telas escritas à mão (estoque.dart) importam Medicamentos daqui.
export 'models.dart';

/// `main` é a porta de entrada: o Dart começa a executar o app por aqui.
/// Devolve um `Future<void>` ("promessa" de que vai terminar, sem resultado) porque
/// tem `await` lá dentro (veja GUIA_FLUTTER.md → async / await / Future).
/// Roda uma única vez, quando o app abre.
Future<void> main() async {
  // (1) Liga o "motor" do Flutter antes de qualquer coisa. É obrigatório quando
  // se faz algo assíncrono (como ler o disco) antes de chamar `runApp`.
  WidgetsFlutterBinding.ensureInitialized();
  // (2) Espera ler do aparelho a URL do servidor que o usuário salvou na tela de
  // login. Precisa vir antes do app abrir, senão a primeira chamada usaria a URL errada.
  await AppConfig.carregar(); // URL do servidor salva na tela de login
  // (3) Desenha o app na tela, começando pelo widget MainApp (a raiz da árvore).
  runApp(const MainApp());
}

// [ESCRITO À MÃO] MainApp original (MaterialApp com home: TelaInicial) — agora StatefulWidget que
// cria o AppStore uma vez, aplica tema claro/escuro e passa por AuthGate antes da TelaInicial
// MainApp é o widget raiz do app. É um StatefulWidget: um widget que precisa
// lembrar de algo que vive mais que um desenho da tela (aqui, o AppStore).
// (veja GUIA_FLUTTER.md → StatefulWidget). Sempre vem em duas classes:
// esta (o "molde") e a _MainAppState abaixo (onde ficam os dados que mudam).
class MainApp extends StatefulWidget {
  // Construtor `const` (objeto fixo, mais leve). `super.key` repassa a chave de identificação ao Flutter.
  const MainApp({super.key});

  @override
  /// O Flutter chama isto uma vez para criar o "estado" (a parte que muda) deste widget.
  State<MainApp> createState() => _MainAppState();
}

/// Estado do MainApp. O `_` no começo significa "privado deste arquivo".
class _MainAppState extends State<MainApp> {
  /// O estado global do app (usuário logado, produtos, tema...). Criado uma só vez
  /// aqui, para não se perder quando a tela se redesenha. Veja GUIA_FLUTTER.md → ChangeNotifier.
  final AppStore _store = AppStore();

  @override
  /// Roda uma única vez, quando este widget nasce. Aqui manda o AppStore começar
  /// (`iniciar`): ler o tema salvo e checar se já existe um login válido.
  void initState() {
    // Sempre chame o `super` primeiro em initState.
    super.initState();
    _store.iniciar();
  }

  @override
  /// Roda quando o widget é destruído (o app fecha). Libera o AppStore para não
  /// deixar "escutas" abertas na memória. Veja GUIA_FLUTTER.md → ciclo de vida do State.
  void dispose() {
    _store.dispose();
    // No dispose, o `super` vai por último (o contrário do initState).
    super.dispose();
  }

  @override
  /// Descreve a árvore de widgets do app inteiro. O Flutter chama `build` sempre que
  /// precisa desenhar (ou redesenhar) este widget. Devolve o widget raiz.
  /// `context` é o "endereço" deste widget na árvore (veja GUIA_FLUTTER.md → BuildContext).
  Widget build(BuildContext context) {
    // AppScope "pendura" o AppStore no topo da árvore: qualquer tela abaixo consegue
    // pegá-lo com AppScope.of(context) (veja app_scope.dart).
    return AppScope(
      store: _store,
      // ListenableBuilder redesenha o que está dentro dele sempre que o AppStore
      // avisar (`notifyListeners`) que mudou algo. Aqui serve para trocar o tema claro/escuro na hora.
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => MaterialApp(
          // MaterialApp: o widget que configura um app no estilo Material (tema, navegação, tela inicial).
          title: 'auraFarma',
          // Esconde a faixa vermelha "DEBUG" do canto da tela.
          debugShowCheckedModeBanner: false,
          // Tema usado no modo claro e no escuro (definidos em theme/app_theme.dart);
          // `themeMode` escolhe qual dos dois vale agora, conforme a preferência do usuário.
          theme: temaClaro(),
          darkTheme: temaEscuro(),
          themeMode: _store.tema,
          // Primeira tela: o AuthGate decide se mostra splash, login ou o app.
          home: const AuthGate(),
        ),
      ),
    );
  }
}
// [FIM ESCRITO À MÃO]

/// Decide entre splash, login e app conforme o estado de autenticação.
///
/// É um StatelessWidget: um widget sem memória, que só desenha algo a partir do que
/// recebe (veja GUIA_FLUTTER.md → StatelessWidget). Olha o estado de autenticação do
/// AppStore e escolhe qual tela mostrar.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  /// Escolhe a tela conforme `status` do AppStore. Como usa `AppScope.of(context)`,
  /// é redesenhado sozinho quando o status muda (ex.: logo depois do login).
  Widget build(BuildContext context) {
    // Cada `case` cobre um valor do enum StatusAuth; o Dart garante que nenhum ficou de fora.
    switch (AppScope.of(context).status) {
      // Ainda checando se existe sessão salva: mostra a splash (tela de espera).
      case StatusAuth.carregando:
        return const _Splash();
      // Sem sessão válida: mostra o login.
      case StatusAuth.deslogado:
        return const TelaLogin();
      // Logado: mostra o app principal com as abas.
      case StatusAuth.logado:
        return const TelaInicial();
    }
  }
}

/// Tela de espera (logo + indicador girando) mostrada enquanto o app verifica o login.
/// Privada (`_`): só o AuthGate usa. StatelessWidget: não guarda nada que muda.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  /// Monta a splash. `AppCores.of(context)` pega as cores do tema atual (claro/escuro),
  /// assim nenhuma cor é escrita "no braço" (veja GUIA_FLUTTER.md → Tema e cores).
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    // Scaffold: o esqueleto de uma tela (fundo + corpo).
    return Scaffold(
      backgroundColor: c.fundo,
      // Center centraliza o filho; Column empilha os filhos na vertical.
      body: Center(
        child: Column(
          // `min`: a coluna ocupa só o espaço necessário (em vez da tela toda).
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quadrado laranja arredondado com a letra "f": o logo provisório do app.
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.destaque,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('f',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold)),
            ),
            // SizedBox vazio, só para dar 24 pixels de espaço entre o logo e o círculo girando.
            const SizedBox(height: 24),
            // Círculo girando ("carregando") na cor de destaque do tema.
            CircularProgressIndicator(color: c.destaque),
          ],
        ),
      ),
    );
  }
}

// [ESCRITO À MÃO] TelaInicial original (IndexedStack + BottomNavigationBar, 5 abas, MudardeTela)
// — mesma ordem de telas; ícones/labels/cores trocados para o Figma (labels minúsculas, barra
// superfície com borda superior, ícones 30, ativo = cor do texto em vez de laranja)
// TelaInicial: o app depois do login. Tem uma barra de 5 abas embaixo e mostra uma tela por aba.
// É StatefulWidget porque precisa lembrar qual aba está selecionada.
class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  /// Cria o estado (a parte que guarda a aba atual).
  State<TelaInicial> createState() => _TelaInicialState();
}

/// Estado da TelaInicial: guarda o índice da aba ativa e a lista de telas.
class _TelaInicialState extends State<TelaInicial> {
  /// Posição da aba selecionada (0 = estoque, 1 = assistente, 2 = contagem, 3 = solicitados, 4 = scanner).
  int _indiceAtual = 0;
  /// As 5 telas, na mesma ordem dos botões da barra de baixo. São criadas uma vez só
  /// e ficam vivas no IndexedStack abaixo (por isso não perdem o que o usuário já digitou ao trocar de aba).
  final List<Widget> _telas = [
    TelaEstoque(),
    TelaAssistente(),
    TelaContagem(),
    TelaSolicitados(),
    TelaScanner(),
  ];

  /// Chamada quando o usuário toca numa aba da barra de baixo. Recebe o `index` da aba
  /// tocada e guarda como aba atual. `setState` avisa o Flutter para redesenhar com a nova aba
  /// (veja GUIA_FLUTTER.md → setState). O nome em maiúscula vem do código original (por isso o `ignore`).
  // ignore: non_constant_identifier_names
  void MudardeTela(int index) {
    setState(() {
      _indiceAtual = index;
    });
  }

  @override
  /// Monta o corpo (uma tela por vez) e a barra de abas de baixo.
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Scaffold(
      // IndexedStack mantém as 5 telas montadas, mas só mostra a de índice `_indiceAtual`
      // (veja GUIA_FLUTTER.md → IndexedStack).
      body: IndexedStack(index: _indiceAtual, children: _telas),
      // DecoratedBox desenha só a linha fina (borda) em cima da barra, separando-a do conteúdo.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.borda)),
        ),
        // A barra de abas. `fixed` = todas as abas visíveis ao mesmo tempo, com o mesmo tamanho.
        child: BottomNavigationBar(
          currentIndex: _indiceAtual,
          // Ao tocar numa aba, chama MudardeTela passando o índice dela.
          onTap: MudardeTela,
          type: BottomNavigationBarType.fixed,
          backgroundColor: c.superficie,
          elevation: 0,
          selectedItemColor: c.texto,
          unselectedItemColor: c.textoSuave,
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          // O `for` dentro da lista cria um item de barra para cada par (ícone, rótulo).
          // `(ic, rotulo)` é um "record" do Dart 3: dois valores juntos.
          // Ícones Iconoir do Figma (cor explícita: ativo = texto, inativo = textoSuave)
          items: [
            for (final (ic, rotulo) in const [
              (Ico.estoque, 'estoque'),
              (Ico.assistente, 'assistente IA'),
              (Ico.contagem, 'contagem'),
              (Ico.solicitados, 'solicitados'),
              (Ico.scanner, 'scanner'),
            ])
              BottomNavigationBarItem(
                // `icon` = aparência da aba inativa; `activeIcon` (abaixo) = aba ativa. 2 px de folga embaixo alinham o ícone com o texto.
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ico(ic, size: 32, color: c.textoSuave),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ico(ic, size: 32, color: c.texto),
                ),
                // Texto pequeno embaixo do ícone.
                label: rotulo,
              ),
          ],
        ),
      ),
    );
  }
}
// [FIM ESCRITO À MÃO]

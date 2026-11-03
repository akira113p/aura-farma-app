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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.carregar(); // URL do servidor salva na tela de login
  runApp(const MainApp());
}

// [ESCRITO À MÃO] MainApp original (MaterialApp com home: TelaInicial) — agora StatefulWidget que
// cria o AppStore uma vez, aplica tema claro/escuro e passa por AuthGate antes da TelaInicial
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final AppStore _store = AppStore();

  @override
  void initState() {
    super.initState();
    _store.iniciar();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: _store,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => MaterialApp(
          title: 'auraFarma',
          debugShowCheckedModeBanner: false,
          theme: temaClaro(),
          darkTheme: temaEscuro(),
          themeMode: _store.tema,
          home: const AuthGate(),
        ),
      ),
    );
  }
}
// [FIM ESCRITO À MÃO]

/// Decide entre splash, login e app conforme o estado de autenticação.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    switch (AppScope.of(context).status) {
      case StatusAuth.carregando:
        return const _Splash();
      case StatusAuth.deslogado:
        return const TelaLogin();
      case StatusAuth.logado:
        return const TelaInicial();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Scaffold(
      backgroundColor: c.fundo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 24),
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
class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  int _indiceAtual = 0;
  final List<Widget> _telas = [
    TelaEstoque(),
    TelaAssistente(),
    TelaContagem(),
    TelaSolicitados(),
    TelaScanner(),
  ];

  // ignore: non_constant_identifier_names
  void MudardeTela(int index) {
    setState(() {
      _indiceAtual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Scaffold(
      body: IndexedStack(index: _indiceAtual, children: _telas),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.borda)),
        ),
        child: BottomNavigationBar(
          currentIndex: _indiceAtual,
          onTap: MudardeTela,
          type: BottomNavigationBarType.fixed,
          backgroundColor: c.superficie,
          elevation: 0,
          selectedItemColor: c.texto,
          unselectedItemColor: c.textoSuave,
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
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
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ico(ic, size: 32, color: c.textoSuave),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ico(ic, size: 32, color: c.texto),
                ),
                label: rotulo,
              ),
          ],
        ),
      ),
    );
  }
}
// [FIM ESCRITO À MÃO]

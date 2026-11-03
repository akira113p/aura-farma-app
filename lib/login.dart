import 'package:flutter/material.dart';

import 'config.dart';
import 'core/api_client.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cartao.dart';

/// Tela de login (mesma conta do auraFarma web).
///
/// É um StatefulWidget: precisa lembrar de coisas que mudam (texto digitado, se está
/// carregando, mensagem de erro). Veja GUIA_FLUTTER.md → StatefulWidget.
/// Mostrada pelo AuthGate (main.dart) enquanto não há sessão. Ao logar, o AuthGate
/// troca esta tela pelo app sozinho (porque o AppStore avisa que o status mudou).
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  /// Cria o estado da tela (onde ficam os dados que mudam).
  State<TelaLogin> createState() => _TelaLoginState();
}

/// Estado da tela de login: campos de texto, flags de carregando/ocultar e erro.
class _TelaLoginState extends State<TelaLogin> {
  /// "Controle remoto" do campo de e-mail/usuário: permite ler o que foi digitado.
  /// Veja GUIA_FLUTTER.md → Controllers. Precisa de `dispose`.
  final _id = TextEditingController();
  /// Controle remoto do campo de senha.
  final _senha = TextEditingController();
  /// true = a senha aparece como bolinhas; o ícone de olho alterna.
  bool _ocultar = true;
  /// true enquanto espera a resposta do servidor (desabilita campos e mostra o botão girando).
  bool _carregando = false;
  /// Mensagem de erro a exibir abaixo da senha; null = sem erro.
  String? _erro;

  @override
  /// Chamado quando a tela sai da árvore. Libera os controllers para não vazar memória.
  void dispose() {
    _id.dispose();
    _senha.dispose();
    super.dispose();
  }

  /// Chamada quando o usuário toca em "Entrar" ou aperta "ok/enter" no campo de senha.
  /// Valida os campos, pede o login ao AppStore e mostra erro se falhar.
  /// Em caso de sucesso não precisa navegar: o AuthGate já troca de tela sozinho.
  Future<void> _entrar() async {
    // Evita duplo toque: se já está enviando, ignora.
    if (_carregando) return;
    // (1) Pega o que foi digitado (trim tira espaços das pontas).
    final id = _id.text.trim();
    if (id.isEmpty || _senha.text.isEmpty) {
      // Campo vazio: mostra o erro sem chamar o servidor. `setState` avisa o Flutter
      // para redesenhar a tela (veja GUIA_FLUTTER.md → setState).
      setState(() => _erro = 'Informe e-mail/usuário e senha.');
      return;
    }
    // (2) Pega o AppStore SEM se inscrever em mudanças (`read`): estamos num callback, não no build.
    final store = AppScope.read(context);
    setState(() {
      // (3) Liga o modo "carregando" e limpa o erro antigo.
      _carregando = true;
      _erro = null;
    });
    try {
      // (4) Espera o servidor responder. Se a senha estiver errada, lança ApiException.
      await store.entrar(id, _senha.text);
    // Erro vindo da API (senha errada, sem conexão...): mostra a mensagem dele.
    // `mounted` checa se a tela ainda existe; se o usuário saiu enquanto esperava,
    // chamar setState daria erro.
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    // `finally` roda sempre (com ou sem erro): desliga o "carregando".
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Chamada ao tocar no texto "Servidor: ..." embaixo. Abre uma caixinha (diálogo)
  /// para digitar outro endereço do backend (útil, por exemplo, com um túnel no 4G).
  /// Salva a escolha e apaga a sessão antiga.
  Future<void> _trocarServidor() async {
    // Guarda o ApiClient antes dos `await`s (depois de esperar, o `context` pode não valer mais).
    final api = AppScope.read(context).api;
    // Controller só do diálogo, já preenchido com a URL atual. Descartado logo abaixo.
    final ctrl = TextEditingController(text: AppConfig.baseUrl);
    // showDialog abre a caixinha e devolve (com await) o que o usuário escolheu:
    // 'salvar', 'padrao' ou null (cancelou / tocou fora). Veja GUIA_FLUTTER.md → Interação.
    final acao = await showDialog<String>(
      context: context,
      // `ctx` é o contexto do diálogo; é com ele que se fecha a caixinha (Navigator.pop).
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor'),
        content: Column(
          // Column ocupa só o necessário; `start` alinha os filhos à esquerda.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Endereço do backend. Ex.: meu-tunel.trycloudflare.com ou 192.168.0.10:4000'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://...'),
              // Apertar "ok" no teclado também salva. `pop(ctx, valor)` fecha o diálogo devolvendo o valor.
              onSubmitted: (_) => Navigator.pop(ctx, 'salvar'),
            ),
          ],
        ),
        // Botões do rodapé do diálogo; cada um fecha devolvendo um valor diferente.
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'padrao'),
              child: const Text('padrão')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'salvar'),
              child: const Text('salvar')),
        ],
      ),
    );
    // Lê o texto e já descarta o controller (não será mais usado).
    final texto = ctrl.text;
    ctrl.dispose();
    // Cancelou: não muda nada.
    if (acao == null) return;
    // 'padrão' manda null (volta ao endereço padrão); 'salvar' manda o texto digitado.
    await AppConfig.definirServidor(acao == 'padrao' ? null : texto);
    // Apaga o cookie guardado: ele valia para o servidor anterior.
    await api.limparSessao(); // o cookie era de outro servidor
    // Redesenha para mostrar a nova URL no rodapé e limpa erro antigo.
    if (mounted) setState(() => _erro = null);
  }

  @override
  /// Monta a tela: logo, campos de e-mail e senha, erro, botão Entrar e o rodapé do servidor.
  Widget build(BuildContext context) {
    // `c` = paleta de cores do tema atual (claro/escuro).
    final c = AppCores.of(context);
    return Scaffold(
      backgroundColor: c.fundo,
      // SafeArea evita que o conteúdo fique sob o notch/barra de status.
      // Center + SingleChildScrollView: centraliza o formulário e deixa rolar quando o teclado ocupa espaço.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Folga de 28 px nas laterais e 24 em cima/embaixo.
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            // Limita a largura a 380 px, para o formulário não ficar enorme em tela larga (tablet/web).
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // `stretch`: os filhos (campos, botão) esticam até a largura toda. Os `SizedBox` entre eles são só espaços verticais.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo: quadrado laranja arredondado com a letra "f" (igual ao da splash).
                  Center(
                    child: Container(
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
                  ),
                  const SizedBox(height: 16),
                  Text('auraFarma',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: c.texto)),
                  const SizedBox(height: 4),
                  Text('Entre na sua conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textoSuave)),
                  const SizedBox(height: 28),
                  // Campo de e-mail/usuário. `enabled: false` durante o carregamento; `autofillHints` ajuda o celular a sugerir login salvo.
                  TextField(
                    controller: _id,
                    enabled: !_carregando,
                    keyboardType: TextInputType.emailAddress,
                    // A tecla do teclado vira "próximo" (pula para a senha).
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration:
                        const InputDecoration(hintText: 'E-mail ou usuário'),
                  ),
                  const SizedBox(height: 12),
                  // Campo de senha. `obscureText` esconde os caracteres.
                  TextField(
                    controller: _senha,
                    enabled: !_carregando,
                    obscureText: _ocultar,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    // Tecla "ok" do teclado faz o login, igual ao botão.
                    onSubmitted: (_) => _entrar(),
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      // Ícone de olho dentro do campo; alterna `_ocultar` com setState.
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultar
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: c.textoSuave,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                    ),
                  ),
                  // `if` dentro da lista: só desenha o erro se existir. `...[ ]` (spread) encaixa os widgets na lista.
                  // `_erro!` = "tenho certeza que não é nulo" (checado na linha acima).
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(_erro!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.perigo, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  // Botão principal (widgets/cartao.dart). Mostra um indicador girando quando `carregando` é true.
                  BotaoLaranja(
                    texto: 'Entrar',
                    carregando: _carregando,
                    onPressed: _entrar,
                  ),
                  const SizedBox(height: 24),
                  Text('Use a mesma conta do auraFarma web.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.textoSuave)),
                  const SizedBox(height: 4),
                  // InkWell deixa o texto "tocável" com efeito de ondinha. `onTap: null` desabilita durante o carregamento.
                  // Row + Flexible: o texto longo da URL é cortado com "..." em vez de estourar a tela.
                  // Toque para trocar o servidor (ex.: URL do túnel quando você está no 4G)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _carregando ? null : _trocarServidor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text('Servidor: ${AppConfig.baseUrl}',
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: c.textoFraco)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined,
                              size: 13, color: c.textoFraco),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// O QUE É ESTE ARQUIVO: a tela "Scanner" do app. Lê o código de barras de um produto
// com a câmera do celular (ou aceita o código digitado) e mostra se ele existe no estoque;
// se não existir, deixa registrar como "solicitado". É uma das abas do app.
// Usa: o pacote `mobile_scanner` (câmera + leitura de código), `AppScope` (acesso ao estoque
// e à API), `app_theme.dart` (cores) e widgets prontos (`Cabecalho`, `BotaoLaranja`, `Selo`...).
// No fim do arquivo há o `_MiraPainter`, que desenha a mira por cima da câmera.
// (veja GUIA_FLUTTER.md → StatefulWidget, IndexedStack, CustomPainter)
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'core/api_client.dart';
import 'models.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cabecalho.dart';
import 'widgets/cartao.dart';
import 'widgets/icones.dart';

/// Fica nulo no app de verdade; `@visibleForTesting` avisa que só os testes devem mexer nele.
/// Só para testes visuais: força "tem câmera" (true/false) sem depender da plataforma.
@visibleForTesting
bool? scannerTemCameraParaTeste;

// [ESCRITO À MÃO] esqueleto TelaScanner/_TelaScanner (StatefulWidget + Scaffold) mantido; o AppBar
// ("Scanner") saiu porque o Cabecalho do Figma o substitui; o State ganhou
// SingleTickerProviderStateMixin (anima a linha de leitura da mira)
// TelaScanner é um StatefulWidget (widget que lembra de coisas que mudam: câmera ligada,
// código lido, últimas leituras). O State correspondente é a `_TelaScanner` logo abaixo.
class TelaScanner extends StatefulWidget {
  const TelaScanner({super.key});

  @override
  State<TelaScanner> createState() => _TelaScanner();
}

// `with SingleTickerProviderStateMixin` dá ao State um "relógio" (ticker) que avisa a cada
// frame da animação; é exigido pelo AnimationController `_linha` (a linha que sobe e desce na mira).
class _TelaScanner extends State<TelaScanner>
    with SingleTickerProviderStateMixin {
  // [FIM ESCRITO À MÃO]

  /// Getter estático: no teste usa o valor forçado; senão, é verdadeiro se NÃO for web e a
  /// plataforma for Android ou iOS (computador/navegador ficam só com o campo de digitar).
  /// Só Android/iOS têm câmera suportada pelo mobile_scanner neste app.
  static bool get _temCamera =>
      scannerTemCameraParaTeste ??
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// MobileScannerController = "controle remoto" da câmera (liga, lanterna, troca de câmera).
  /// Não-nulo só enquanto a câmera está ligada (a tela vive num IndexedStack,
  /// então nada liga sozinho: só o toque no botão cria o controller).
  MobileScannerController? _camera;
  // _codigo = último código lido/digitado (nulo = ainda não leu nada; some ao tocar em "limpar").
  String? _codigo;
  // _recentes = até 5 últimos códigos buscados, mais novo primeiro (viram "chips" tocáveis).
  final List<String> _recentes = [];

  // _campo = controle remoto do campo onde se digita o código de barras.
  final _campo = TextEditingController();
  // _rolagem = controla a rolagem da tela (para descer até o resultado depois de uma leitura).
  final _rolagem = ScrollController();
  // _linha = animação que vai de 0 a 1 em 1,8 s e volta (vira a linha de leitura da mira).
  // `late final` = só é criada na primeira vez que for usada. `vsync: this` liga ao relógio do State.
  late final AnimationController _linha = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  /// Roda quando algo de que a tela depende muda (inclusive logo após nascer). Aqui é usada
  /// para DESLIGAR A CÂMERA quando o usuário troca de aba.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // (Explicando: TickerMode é um interruptor que o Flutter usa para pausar animações de telas
    // escondidas; se estiver desligado para esta tela e a câmera estiver ligada, é hora de desligá-la.)
    // A tela vive num IndexedStack: ao trocar de aba ela continua montada, mas o
    // IndexedStack desliga o TickerMode das abas escondidas. Usa isso p/ não deixar
    // a câmera ligada em segundo plano.
    if (!TickerMode.valuesOf(context).enabled && _camera != null) {
      // Guarda a câmera numa variável local e zera `_camera` (o `!` afirma que não é nulo, já checado acima).
      final cam = _camera!;
      _camera = null;
      _linha.stop();
      // Só descarta o controller DEPOIS do próximo frame: assim o widget da câmera (MobileScanner)
      // já saiu da tela e não tenta usar um controller morto. `mounted` evita setState com a tela fechada.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cam.dispose();
        if (mounted) setState(() {});
      });
    }
  }

  /// Roda uma vez quando a tela é destruída: libera câmera, animação, campo de texto e rolagem
  /// (senão ficariam ocupando memória / mantendo a câmera ligada).
  @override
  void dispose() {
    _camera?.dispose();
    _linha.dispose();
    _campo.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  /// Desliga a câmera (se estiver ligada). Chamada ao tocar no botão parar, ao detectar um
  /// código e ao trocar de aba (esta última por outro caminho, no didChangeDependencies).
  void _desligar() {
    final cam = _camera;
    if (cam == null) return;
    _linha.stop();
    // Desmonta o MobileScanner primeiro (setState tira `_camera` da tela) e só depois, no
    // próximo frame, descarta o controller. Fazer ao contrário poderia dar erro por uso de
    // controller já descartado.
    // desmonta o MobileScanner primeiro e só depois descarta o controller
    setState(() => _camera = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => cam.dispose());
  }

  /// Liga ou desliga a câmera. Chamada ao tocar no botão laranja grande.
  /// Sem câmera suportada (computador) não faz nada. Se já está ligada, desliga; senão cria
  /// um novo controller (só os formatos de código que interessam) e inicia a animação.
  void _alternarCamera() {
    if (!_temCamera) return;
    if (_camera != null) {
      _desligar();
      return;
    }
    // Liga: limpa o código anterior e cria o controller dentro de setState para a tela mostrar a câmera.
    // Formatos aceitos: EAN-13/EAN-8/UPC (códigos de produtos), Code128 e QR Code.
    // `noDuplicates` = não repete a detecção do mesmo código a cada frame.
    setState(() {
      _codigo = null;
      _camera = MobileScannerController(
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.qrCode,
        ],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    });
    // `repeat(reverse: true)` faz a linha de leitura ir e voltar sem parar.
    _linha.repeat(reverse: true);
  }

  /// Chamada pelo MobileScanner toda vez que a câmera detecta algo ([captura] traz a lista de
  /// códigos vistos). Pega o primeiro que tiver texto e manda buscar no estoque.
  void _aoDetectar(BarcodeCapture captura) {
    for (final b in captura.barcodes) {
      // `rawValue?.trim()`: o valor pode ser nulo (`?.` só chama trim se existir).
      final valor = b.rawValue?.trim();
      if (valor != null && valor.isNotEmpty) {
        _buscar(valor, daCamera: true);
        return;
      }
    }
  }

  /// [bruto] é o texto do código; [daCamera] diz se veio da câmera (então dá uma vibração leve).
  /// Passos: (1) limpa e valida; (2) desliga a câmera; (3) guarda o código e atualiza as
  /// "últimas leituras" (máx. 5, sem repetir); (4) limpa o campo e fecha o teclado; (5) rola até o resultado.
  /// Procura o código no estoque (vindo da câmera, do campo ou das últimas leituras).
  void _buscar(String bruto, {bool daCamera = false}) {
    final valor = bruto.trim();
    if (valor.isEmpty) return;
    // Vibração curta no celular como confirmação de que leu.
    if (daCamera) HapticFeedback.mediumImpact();
    _desligar();
    // `..remove(valor)..insert(0, valor)` é o operador de cascata: executa vários métodos na mesma lista.
    // Remove o código se já estava na lista e põe no início (assim o repetido sobe para o topo).
    setState(() {
      _codigo = valor;
      _recentes
        ..remove(valor)
        ..insert(0, valor);
      // Se passou de 5 itens, apaga os mais antigos (do índice 5 em diante).
      if (_recentes.length > 5) _recentes.removeRange(5, _recentes.length);
    });
    _campo.clear();
    // Tira o foco do campo, o que fecha o teclado.
    FocusManager.instance.primaryFocus?.unfocus();
    // (Roda depois do frame porque o cartão de resultado só existe após o setState acima.)
    // leva o resultado para a vista (ele fica abaixo do visor)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rolagem.hasClients) return;
      _rolagem.animateTo(_rolagem.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  /// Registra o código lido como "solicitado" (produto pedido que não temos) no servidor.
  /// Chamada ao tocar em "registrar como solicitado". Mostra um aviso rápido (SnackBar) com o resultado.
  Future<void> _registrarSolicitado(String codigo) async {
    // `read`: só queremos o store agora, sem reagir a mudanças. O ScaffoldMessenger é guardado
    // ANTES do `await` porque depois de esperar não é seguro usar o `context`.
    final store = AppScope.read(context);
    final msg = ScaffoldMessenger.of(context);
    try {
      // `await` espera o servidor confirmar. Se a API devolver erro conhecido (`ApiException`), mostra a mensagem dele.
      await store.registrarSolicitacao('Código $codigo', 'Lido no scanner');
      msg.showSnackBar(const SnackBar(content: Text('Registrado em solicitados')));
    } on ApiException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ------------------------------------------------------------------ visor

  /// Mostra um ícone grande, um título e uma frase de ajuda, centralizados (Center + Column).
  /// Mensagem dentro do visor (sem câmera, câmera desligada, erro/permissão).
  Widget _aviso(AppCores c, String titulo, String sub, {Ico icone = Ico.scanner}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ico(icone, size: 44, color: c.textoFraco),
            const SizedBox(height: 12),
            Text(titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: c.texto)),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.textoSuave)),
          ],
        ),
      ),
    );
  }

  /// Botãozinho redondo (fundo preto translúcido) usado sobre a imagem da câmera.
  /// [icone] = desenho, [dica] = texto que aparece ao segurar (Tooltip), [onTap] = o que fazer ao tocar.
  /// Material + InkWell dão a "ondinha" ao toque; CircleBorder deixa tudo redondo.
  Widget _botaoVisor(IconData icone, String dica, VoidCallback onTap) {
    return Tooltip(
      message: dica,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icone, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// `Positioned` cola o conjunto no topo do Stack (10 px de cada lado).
  /// Controles sobre a imagem da câmera: dica à esquerda, lanterna e troca de câmera à direita.
  Widget _controlesCamera(MobileScannerController cam) {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Row(
        children: [
          // Flexible deixa a pílula de dica encolher se faltar espaço; Spacer empurra os botões para a direita.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Aponte para o código de barras',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ),
          const Spacer(),
          // ValueListenableBuilder redesenha só este botão quando o estado da câmera muda (lanterna ligada,
          // desligada ou indisponível). Se o aparelho não tem lanterna, não mostra o botão (SizedBox.shrink = nada).
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: cam,
            builder: (_, v, _) {
              if (v.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final ligada = v.torchState == TorchState.on;
              return _botaoVisor(
                ligada ? Icons.flash_on : Icons.flash_off,
                ligada ? 'Apagar lanterna' : 'Acender lanterna',
                cam.toggleTorch,
              );
            },
          ),
          const SizedBox(width: 6),
          _botaoVisor(Icons.cameraswitch_outlined, 'Trocar câmera', cam.switchCamera),
        ],
      ),
    );
  }

  /// O "visor": a caixa quadrada onde aparece a câmera, a mira e os controles.
  /// Sem câmera suportada (computador) mostra só um cartão baixo com um aviso.
  Widget _visor(AppCores c) {
    final cam = _camera;
    // moldura = fundo, cantos arredondados e borda do visor.
    final moldura = BoxDecoration(
      color: c.superficie,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.borda),
    );

    // Computador/web: não há câmera. Cartão compacto — o campo de digitação é o caminho.
    if (!_temCamera) {
      return Container(
        height: 150,
        decoration: moldura,
        child: _aviso(c, 'Câmera indisponível neste computador',
            'Digite o código de barras do produto no campo abaixo.'),
      );
    }

    // AspectRatio 1 = quadrado. `clipBehavior` recorta o que passar dos cantos arredondados.
    // Stack empilha em camadas (de baixo para cima): câmera/aviso, mira desenhada, controles.
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: moldura,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cam == null)
              _aviso(c, 'Câmera desligada', 'Toque no botão laranja para escanear.')
            else
              // MobileScanner = o widget do pacote que mostra a imagem da câmera e chama `onDetect` ao ler um código.
              // `errorBuilder` escolhe a mensagem se a câmera falhar (ex.: permissão negada).
              MobileScanner(
                controller: cam,
                onDetect: _aoDetectar,
                errorBuilder: (ctx, erro) => _aviso(
                  c,
                  erro.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Permissão da câmera negada'
                      : 'Não foi possível usar a câmera',
                  'Você ainda pode digitar o código no campo abaixo.',
                  icone: Ico.camera,
                ),
              ),
            // IgnorePointer: a mira é só desenho e não deve "roubar" toques dos botões por baixo.
            // CustomPaint + `_MiraPainter` desenham a mira (veja a classe no fim do arquivo).
            IgnorePointer(
              child: CustomPaint(
                painter: _MiraPainter(
                    linha: _linha, cor: c.destaque, ativa: cam != null),
              ),
            ),
            if (cam != null) _controlesCamera(cam),
          ],
        ),
      ),
    );
  }

  /// Mostra "parar" (quadrado) se a câmera está ligada ou o ícone de câmera se está desligada.
  /// Botão laranja grande do Figma, sobreposto à borda inferior do visor.
  Widget _botaoCamera(AppCores c) {
    return Material(
      color: c.destaque,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _alternarCamera,
        child: SizedBox(
          width: 100,
          height: 110,
          child: Center(
            child: _camera != null
                ? const Icon(Icons.stop_rounded, color: Colors.white, size: 56)
                : ico(Ico.camera, color: Colors.white, size: 60),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------- digitar / recentes

  /// Campo para digitar o código de barras + botão "buscar" (caminho alternativo à câmera).
  /// Buscar acontece ao tocar no botão ou ao apertar "buscar" no teclado (onSubmitted).
  Widget _campoManual(AppCores c) {
    // Bordas do TextField desligadas: a borda visível é a do Container em volta.
    const semBorda = InputBorder.none;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borda),
      ),
      child: Row(
        children: [
          ico(Ico.scanner, size: 22, color: c.textoSuave),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _campo,
              textInputAction: TextInputAction.search,
              onSubmitted: _buscar,
              style: TextStyle(fontSize: 14, color: c.texto),
              decoration: InputDecoration(
                hintText: 'Digitar código de barras',
                hintStyle: TextStyle(fontSize: 14, color: c.textoFraco),
                filled: false,
                border: semBorda,
                enabledBorder: semBorda,
                focusedBorder: semBorda,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          BotaoLaranja(texto: 'buscar', onPressed: () => _buscar(_campo.text)),
        ],
      ),
    );
  }

  /// "Últimas leituras": chips com os códigos recentes; tocar em um busca de novo.
  /// Wrap = como uma Row que quebra para a linha de baixo quando falta espaço.
  Widget _recentesWidget(AppCores c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Últimas leituras',
              style: TextStyle(fontSize: 12, color: c.textoSuave)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _recentes)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _buscar(r),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.borda),
                    ),
                    child: Text(r,
                        style: TextStyle(fontSize: 12, color: c.texto)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- resultado

  /// Uma "estatística" do resultado (ex.: rótulo "Estoque" e valor "12"). Expanded divide
  /// o espaço igualmente entre as colunas da linha. [cor] é opcional (padrão: cor do texto).
  Widget _estat(AppCores c, String rotulo, String valor, {Color? cor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: TextStyle(fontSize: 11, color: c.textoSuave)),
          const SizedBox(height: 2),
          Text(valor,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: cor ?? c.texto)),
        ],
      ),
    );
  }

  /// Monta o cartão de resultado para o [codigo] lido: ou os dados do medicamento encontrado
  /// ou um aviso de "não cadastrado" com botão para registrar como solicitado.
  /// Chamada pelo build quando `_codigo` não é nulo.
  Widget _resultado(String codigo) {
    final c = AppCores.of(context);
    // Busca no estoque (via AppScope.of: se o estoque mudar, o cartão se atualiza). Nulo = não achou.
    final med = AppScope.of(context).buscarPorCodigo(codigo);

    // `final Widget corpo;` é declarada agora e recebe valor em um dos dois ramos do if/else.
    final Widget corpo;
    // Achou: nome, código, selos (categoria e se o estoque está baixo) e 3 estatísticas
    // (quantidade, mínimo, preço). Quantidade fica vermelha se estiver em baixa, verde se ok.
    if (med != null) {
      corpo = Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(med.nome,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: c.texto)),
            const SizedBox(height: 2),
            Text(med.codigo,
                style: TextStyle(fontSize: 11, color: c.textoSuave)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (med.categorias.isNotEmpty)
                Selo(med.categorias, tom: TomSelo.neutro),
              med.emBaixa
                  ? const Selo('Estoque baixo', tom: TomSelo.aviso)
                  : const Selo('Em estoque', tom: TomSelo.sucesso),
            ]),
            const SizedBox(height: 14),
            Divider(height: 1, color: c.borda.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Row(children: [
              _estat(c, 'Estoque', '${med.quantidade}',
                  cor: med.emBaixa ? c.perigo : c.sucesso),
              _estat(c, 'Mínimo', '${med.minimo}'),
              _estat(c, 'Preço', formatarPreco(med.preco)),
            ]),
          ],
        ),
      );
    } else {
      // Não achou: aviso + botão que registra o código como solicitado.
      corpo = Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ico(Ico.busca, size: 22, color: c.aviso),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Produto não cadastrado no estoque',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.texto)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Nenhum item com o código $codigo.',
                style: TextStyle(fontSize: 12, color: c.textoSuave)),
            const SizedBox(height: 12),
            BotaoLaranja(
              texto: 'registrar como solicitado',
              onPressed: () => _registrarSolicitado(codigo),
            ),
          ],
        ),
      );
    }

    // Parte de fora do cartão: uma etiqueta laranja colada no topo (Figma) com o código lido,
    // o botão "limpar" ao lado e, embaixo, a caixa com o `corpo`. O canto de cima à esquerda da
    // caixa é reto para encaixar na etiqueta (só os outros 3 cantos são arredondados).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // etiqueta laranja colada no topo do cartão (Figma) + fechar
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.destaque,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Código de barras: ',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF0A0A0A))),
                      TextSpan(
                          text: codigo,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _codigo = null),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: c.textoSuave),
              child: const Text('limpar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: c.superficie,
            border: Border.all(color: c.borda),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: corpo,
        ),
      ],
    );
  }

  /// Monta a tela toda. Chamado a cada mudança de estado.
  /// Coluna rolável (SingleChildScrollView) de cima para baixo: cabeçalho, texto de ajuda,
  /// visor (+ botão da câmera), campo de digitação, resultado (se houver) e últimas leituras.
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _rolagem,
          // (Center + ConstrainedBox com maxWidth 440 limitam a largura da coluna.)
          // Em janela larga (computador) o conteúdo fica centrado, sem esticar.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Cabecalho(
                    titulo: 'Scanner',
                    subtitulo: 'Verificar código de barras',
                    descricao:
                        'Escaneie o código do produto para acessar seu registro.',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
                    child: Text(
                        _temCamera
                            ? 'Use a câmera do seu dispositivo'
                            : 'Digite o código de barras do produto',
                        style: TextStyle(fontSize: 12, color: c.textoSuave)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    // O botão laranja (110 de altura) fica metade dentro e metade fora do visor.
                    // O espaço de baixo é DENTRO do Stack: fora dos limites do pai o Flutter
                    // não entrega toques e a metade de baixo do botão ficaria morta.
                    child: _temCamera
                        ? Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 55),
                                child: _visor(c),
                              ),
                              _botaoCamera(c),
                            ],
                          )
                        : _visor(c),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _campoManual(c),
                  ),
                  // `if` dentro da lista: mostra o resultado só se já há um código lido.
                  if (_codigo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: _resultado(_codigo!),
                    ),
                  if (_recentes.isNotEmpty) _recentesWidget(c),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// É um CustomPainter: uma classe que desenha "à mão" num Canvas (a "tela em branco"),
/// usando linhas, retângulos e caminhos, em vez de widgets prontos. O Flutter chama o
/// método `paint` sempre que precisa desenhar e informa o tamanho disponível (`size`).
/// (veja GUIA_FLUTTER.md → CustomPainter)
/// Mira do leitor: cantos laranja num retângulo central; com a câmera ligada escurece o
/// resto e passa uma linha de leitura animada.
class _MiraPainter extends CustomPainter {
  // `repaint: linha` liga o painter à animação: a cada frame dela, o Flutter redesenha
  // SÓ a mira, sem reconstruir a tela inteira.
  _MiraPainter({required this.linha, required this.cor, required this.ativa})
      : super(repaint: linha);

  // linha = animação (0 a 1) que controla a posição da linha de leitura.
  final Animation<double> linha;
  // cor = laranja da marca (vinda do tema).
  final Color cor;
  // ativa = true quando a câmera está ligada (aí escurece o fundo e mostra a linha animada).
  final bool ativa;

  /// Faz o desenho. [canvas] é a tela onde se desenha; [size] é o tamanho da área disponível.
  @override
  void paint(Canvas canvas, Size size) {
    // (1) `alvo`: o retângulo da mira, centralizado, com 78% da largura e 40% da altura do visor.
    final alvo = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.78,
      height: size.height * 0.40,
    );

    // (2) Só com a câmera ligada: escurece tudo FORA da mira. `tudo` é um caminho (Path) cobrindo
    // o visor inteiro; `furo` é o retângulo da mira com cantos arredondados (raio 14).
    // `Path.combine(difference, ...)` subtrai o furo do total, sobrando uma "moldura" que é
    // pintada de preto com 50% de opacidade. Resultado: o centro fica claro e a borda escura.
    if (ativa) {
      final tudo = Path()..addRect(Offset.zero & size);
      final furo = Path()
        ..addRRect(RRect.fromRectAndRadius(alvo, const Radius.circular(14)));
      canvas.drawPath(Path.combine(PathOperation.difference, tudo, furo),
          Paint()..color = Colors.black.withValues(alpha: 0.5));
    }

    // (3) `cantos` é o "pincel" (Paint) dos cantos da mira: laranja (mais apagado se a câmera
    // está desligada), só traço (stroke), 4 px de espessura e pontas arredondadas.
    final cantos = Paint()
      ..color = ativa ? cor : cor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // A função local `canto` desenha um "L": uma linha horizontal e uma vertical a partir do
    // ponto [p]. dx/dy valem 1 ou -1 e dizem a direção (para a direita/esquerda, para baixo/cima).
    const t = 26.0; // comprimento de cada braço do canto
    void canto(Offset p, double dx, double dy) {
      canvas.drawLine(p, p + Offset(dx * t, 0), cantos);
      canvas.drawLine(p, p + Offset(0, dy * t), cantos);
    }

    // Os quatro cantos do retângulo: cada um com a direção que aponta para DENTRO da mira.
    canto(alvo.topLeft, 1, 1);
    canto(alvo.topRight, -1, 1);
    canto(alvo.bottomLeft, 1, -1);
    canto(alvo.bottomRight, -1, -1);

    // (4) Só com a câmera ligada: desenha a linha de leitura. `y` vai do topo ao fundo da mira
    // (com 10 px de folga em cada ponta) conforme `linha.value` (0 a 1); `Curves.easeInOut`
    // suaviza: acelera no meio e desacelera nas pontas. A linha é horizontal, 12 px mais curta
    // que a mira de cada lado, e o `MaskFilter.blur` dá um leve brilho (desfoque) a ela.
    if (ativa) {
      final y = alvo.top +
          10 +
          (alvo.height - 20) * Curves.easeInOut.transform(linha.value);
      canvas.drawLine(
        Offset(alvo.left + 12, y),
        Offset(alvo.right - 12, y),
        Paint()
          ..color = cor
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
      );
    }
  }

  /// Diz ao Flutter se precisa redesenhar quando o painter é recriado. Só vale a pena se a cor
  /// ou o estado ligado/desligado mudaram. (A animação se redesenha sozinha via `repaint`.)
  @override
  bool shouldRepaint(_MiraPainter old) => old.cor != cor || old.ativa != ativa;
}

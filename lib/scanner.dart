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

/// Só para testes visuais: força "tem câmera" (true/false) sem depender da plataforma.
@visibleForTesting
bool? scannerTemCameraParaTeste;

// [ESCRITO À MÃO] esqueleto TelaScanner/_TelaScanner (StatefulWidget + Scaffold) mantido; o AppBar
// ("Scanner") saiu porque o Cabecalho do Figma o substitui; o State ganhou
// SingleTickerProviderStateMixin (anima a linha de leitura da mira)
class TelaScanner extends StatefulWidget {
  const TelaScanner({super.key});

  @override
  State<TelaScanner> createState() => _TelaScanner();
}

class _TelaScanner extends State<TelaScanner>
    with SingleTickerProviderStateMixin {
  // [FIM ESCRITO À MÃO]

  /// Só Android/iOS têm câmera suportada pelo mobile_scanner neste app.
  static bool get _temCamera =>
      scannerTemCameraParaTeste ??
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// Não-nulo só enquanto a câmera está ligada (a tela vive num IndexedStack,
  /// então nada liga sozinho: só o toque no botão cria o controller).
  MobileScannerController? _camera;
  String? _codigo;
  final List<String> _recentes = [];

  final _campo = TextEditingController();
  final _rolagem = ScrollController();
  late final AnimationController _linha = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A tela vive num IndexedStack: ao trocar de aba ela continua montada, mas o
    // IndexedStack desliga o TickerMode das abas escondidas. Usa isso p/ não deixar
    // a câmera ligada em segundo plano.
    if (!TickerMode.valuesOf(context).enabled && _camera != null) {
      final cam = _camera!;
      _camera = null;
      _linha.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cam.dispose();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _linha.dispose();
    _campo.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  void _desligar() {
    final cam = _camera;
    if (cam == null) return;
    _linha.stop();
    // desmonta o MobileScanner primeiro e só depois descarta o controller
    setState(() => _camera = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => cam.dispose());
  }

  void _alternarCamera() {
    if (!_temCamera) return;
    if (_camera != null) {
      _desligar();
      return;
    }
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
    _linha.repeat(reverse: true);
  }

  void _aoDetectar(BarcodeCapture captura) {
    for (final b in captura.barcodes) {
      final valor = b.rawValue?.trim();
      if (valor != null && valor.isNotEmpty) {
        _buscar(valor, daCamera: true);
        return;
      }
    }
  }

  /// Procura o código no estoque (vindo da câmera, do campo ou das últimas leituras).
  void _buscar(String bruto, {bool daCamera = false}) {
    final valor = bruto.trim();
    if (valor.isEmpty) return;
    if (daCamera) HapticFeedback.mediumImpact();
    _desligar();
    setState(() {
      _codigo = valor;
      _recentes
        ..remove(valor)
        ..insert(0, valor);
      if (_recentes.length > 5) _recentes.removeRange(5, _recentes.length);
    });
    _campo.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    // leva o resultado para a vista (ele fica abaixo do visor)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rolagem.hasClients) return;
      _rolagem.animateTo(_rolagem.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _registrarSolicitado(String codigo) async {
    final store = AppScope.read(context);
    final msg = ScaffoldMessenger.of(context);
    try {
      await store.registrarSolicitacao('Código $codigo', 'Lido no scanner');
      msg.showSnackBar(const SnackBar(content: Text('Registrado em solicitados')));
    } on ApiException catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ------------------------------------------------------------------ visor

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

  /// Controles sobre a imagem da câmera: dica à esquerda, lanterna e troca de câmera à direita.
  Widget _controlesCamera(MobileScannerController cam) {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Row(
        children: [
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

  Widget _visor(AppCores c) {
    final cam = _camera;
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

  Widget _campoManual(AppCores c) {
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

  Widget _resultado(String codigo) {
    final c = AppCores.of(context);
    final med = AppScope.of(context).buscarPorCodigo(codigo);

    final Widget corpo;
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

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _rolagem,
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

/// Mira do leitor: cantos laranja num retângulo central; com a câmera ligada escurece o
/// resto e passa uma linha de leitura animada.
class _MiraPainter extends CustomPainter {
  _MiraPainter({required this.linha, required this.cor, required this.ativa})
      : super(repaint: linha);

  final Animation<double> linha;
  final Color cor;
  final bool ativa;

  @override
  void paint(Canvas canvas, Size size) {
    final alvo = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.78,
      height: size.height * 0.40,
    );

    if (ativa) {
      final tudo = Path()..addRect(Offset.zero & size);
      final furo = Path()
        ..addRRect(RRect.fromRectAndRadius(alvo, const Radius.circular(14)));
      canvas.drawPath(Path.combine(PathOperation.difference, tudo, furo),
          Paint()..color = Colors.black.withValues(alpha: 0.5));
    }

    final cantos = Paint()
      ..color = ativa ? cor : cor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const t = 26.0; // comprimento de cada braço do canto
    void canto(Offset p, double dx, double dy) {
      canvas.drawLine(p, p + Offset(dx * t, 0), cantos);
      canvas.drawLine(p, p + Offset(0, dy * t), cantos);
    }

    canto(alvo.topLeft, 1, 1);
    canto(alvo.topRight, -1, 1);
    canto(alvo.bottomLeft, 1, -1);
    canto(alvo.bottomRight, -1, -1);

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

  @override
  bool shouldRepaint(_MiraPainter old) => old.cor != cor || old.ativa != ativa;
}

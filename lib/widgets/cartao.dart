// O QUE É ESTE ARQUIVO
// Biblioteca de peças visuais pequenas e reutilizáveis: o cartão com faixa laranja
// (`CartaoComFaixa`), o aviso de lista vazia (`Vazio`), o selo/etiqueta colorida
// (`Selo`) e o botão laranja principal (`BotaoLaranja`).
// As telas (estoque, contagem, solicitados, login...) usam essas peças para manter
// o mesmo visual do Figma. Dependem das cores do tema (theme/app_theme.dart) e
// dos ícones (icones.dart).
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'icones.dart';

/// Cartão com faixa laranja no topo ("Título  n algo").
///
/// StatelessWidget: widget "sem memória", só desenha o que recebe.
/// (veja GUIA_FLUTTER.md → StatelessWidget)
class CartaoComFaixa extends StatelessWidget {
  const CartaoComFaixa({
    super.key,
    required this.titulo,
    required this.contador,
    required this.child,
  });

  /// Texto da faixa laranja, à esquerda (ex.: "Produtos").
  final String titulo;

  /// Texto menor ao lado do título, em branco (ex.: "12 itens").
  final String contador;

  /// O conteúdo do cartão, que aparece abaixo da faixa (qualquer widget).
  final Widget child;

  /// Desenha a faixa laranja em cima e o conteúdo [child] embaixo, tudo dentro
  /// de uma caixa com borda arredondada. Chamado pelo Flutter ao desenhar a tela.
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    // Container: uma caixa com cor, borda e cantos arredondados.
    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borda),
      ),
      // antiAlias "corta" o conteúdo nos cantos arredondados; sem isso a faixa
      // laranja (retangular) vazaria para fora das pontas curvas.
      clipBehavior: Clip.antiAlias,
      // Column empilha a faixa e o conteúdo na vertical.
      child: Column(
        // min = a coluna ocupa só a altura necessária (não tenta esticar).
        mainAxisSize: MainAxisSize.min,
        // stretch = os filhos ocupam toda a largura do cartão.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A faixa laranja do topo, com altura fixa de 36.
          Container(
            height: 36,
            color: c.destaque,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            // Row: título e contador lado a lado.
            child: Row(
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF0A0A0A))),
                // SizedBox: caixa vazia só para dar espaço entre os textos.
                const SizedBox(width: 10),
                Text(contador,
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Estado vazio: ícone num quadrado cinza arredondado + texto suave.
///
/// Mostrado quando uma lista não tem nada para exibir (ex.: "Nenhum item").
class Vazio extends StatelessWidget {
  const Vazio({super.key, required this.icone, required this.texto});

  /// Qual ícone aparece no quadradinho (veja o enum `Ico` em icones.dart).
  final Ico icone;

  /// Mensagem exibida abaixo do ícone.
  final String texto;

  /// Desenha o quadradinho com o ícone e a mensagem, centralizados.
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Padding(
      // symmetric: mesma folga em cima/embaixo (24) e nos lados (16).
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quadrado de 48x48 com fundo cinza bem transparente (alpha 0.18 = 18%
          // de opacidade) e cantos arredondados.
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.borda.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            // Centraliza o ícone dentro do quadrado.
            alignment: Alignment.center,
            child: ico(icone, color: c.textoSuave, size: 28),
          ),
          const SizedBox(height: 10),
          Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textoSuave)),
        ],
      ),
    );
  }
}

/// Os "tons" possíveis de um [Selo]: define a cor do fundo e do texto.
enum TomSelo { destaque, sucesso, aviso, neutro }

/// Pílula (badge).
///
/// Uma etiqueta pequena e arredondada com um texto curto (ex.: "Em baixa").
class Selo extends StatelessWidget {
  /// O texto é posicional (`Selo('Ok')`); o tom é nomeado e tem padrão `destaque`.
  const Selo(this.texto, {super.key, this.tom = TomSelo.destaque});

  /// Texto escrito dentro da pílula.
  final String texto;

  /// Escolhe o esquema de cores da pílula.
  final TomSelo tom;

  /// Desenha a pílula com as cores correspondentes ao [tom].
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    // Record (Dart 3): guarda dois valores juntos, aqui (cor do fundo, cor do texto).
    // O `switch` escolhe o par conforme o tom. As cores com alpha 0.15 ficam
    // quase transparentes, formando um fundo suave da mesma cor do texto.
    final (Color fundo, Color fonte) = switch (tom) {
      TomSelo.destaque => (c.destaqueSuave, c.destaque),
      TomSelo.sucesso => (c.sucesso.withValues(alpha: 0.15), c.sucesso),
      TomSelo.aviso => (c.aviso.withValues(alpha: 0.15), c.aviso),
      TomSelo.neutro => (c.borda.withValues(alpha: 0.2), c.textoSuave),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fundo,
        // 999 = raio enorme, o que deixa as pontas totalmente redondas (pílula).
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: fonte)),
    );
  }
}

/// Botão primário laranja (raio 12).
///
/// Pode mostrar texto + ícone, ou uma rodinha girando enquanto algo carrega.
class BotaoLaranja extends StatelessWidget {
  const BotaoLaranja({
    super.key,
    required this.texto,
    this.icone,
    required this.onPressed,
    this.carregando = false,
  });

  /// Rótulo do botão.
  final String texto;

  /// Ícone opcional, mostrado à esquerda do texto.
  final Ico? icone;

  /// O que acontece ao tocar. `VoidCallback?` = uma função sem parâmetros que
  /// pode ser nula; passar `null` deixa o botão desabilitado (cinza, sem toque).
  final VoidCallback? onPressed;

  /// Quando true, troca o texto por uma rodinha de carregamento e bloqueia o toque
  /// (evita o usuário tocar duas vezes enquanto a ação anterior não terminou).
  final bool carregando;

  /// Desenha o botão. Altura fixa de 44 (tamanho confortável para o dedo).
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return SizedBox(
      height: 44,
      child: FilledButton(
        // Estilo: cores normal e desabilitada (40% de opacidade), cantos e folga.
        style: FilledButton.styleFrom(
          backgroundColor: c.destaque,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.destaque.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        // Enquanto carrega, `null` desabilita o botão; senão usa a ação recebida.
        onPressed: carregando ? null : onPressed,
        // Operador `? :` (se/senão): rodinha se estiver carregando, senão o conteúdo normal.
        child: carregando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                // min = a linha encolhe ao tamanho do conteúdo (botão não estica).
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Só mostra o ícone (e o espaço depois dele) se um foi informado.
                  if (icone != null) ...[
                    // `icone!` = já checamos que não é nulo.
                    ico(icone!, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  // Flexible deixa o texto encolher/cortar com "..." se faltar espaço.
                  Flexible(
                    child: Text(texto,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
      ),
    );
  }
}

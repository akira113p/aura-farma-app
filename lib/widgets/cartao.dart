import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'icones.dart';

/// Cartão com faixa laranja no topo ("Título  n algo").
class CartaoComFaixa extends StatelessWidget {
  const CartaoComFaixa({
    super.key,
    required this.titulo,
    required this.contador,
    required this.child,
  });

  final String titulo;
  final String contador;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            color: c.destaque,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF0A0A0A))),
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
class Vazio extends StatelessWidget {
  const Vazio({super.key, required this.icone, required this.texto});

  final Ico icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.borda.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
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

enum TomSelo { destaque, sucesso, aviso, neutro }

/// Pílula (badge).
class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, this.tom = TomSelo.destaque});

  final String texto;
  final TomSelo tom;

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: fonte)),
    );
  }
}

/// Botão primário laranja (raio 12).
class BotaoLaranja extends StatelessWidget {
  const BotaoLaranja({
    super.key,
    required this.texto,
    this.icone,
    required this.onPressed,
    this.carregando = false,
  });

  final String texto;
  final Ico? icone;
  final VoidCallback? onPressed;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return SizedBox(
      height: 44,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.destaque,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.destaque.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: carregando ? null : onPressed,
        child: carregando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icone != null) ...[
                    ico(icone!, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
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

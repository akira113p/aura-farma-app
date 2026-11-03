import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'icones.dart';

/// "Título / subtítulo" + descrição + botão de tema. Usar dentro de SafeArea.
class Cabecalho extends StatelessWidget {
  const Cabecalho({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.descricao,
    this.acoes,
  });

  final String titulo;
  final String subtitulo;
  final String? descricao;

  /// Botões extras exibidos antes do botão de tema.
  final List<Widget>? acoes;

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: titulo,
                      style: TextStyle(fontSize: 18, color: c.texto),
                    ),
                    TextSpan(
                      text: ' / $subtitulo',
                      style: TextStyle(fontSize: 15, color: c.textoSuave),
                    ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...?acoes,
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: escuro ? 'Tema claro' : 'Tema escuro',
                icon: ico(escuro ? Ico.sol : Ico.lua,
                    color: c.textoSuave, size: 24),
                onPressed: () => AppScope.read(context).alternarTema(),
              ),
            ],
          ),
          if (descricao != null) ...[
            const SizedBox(height: 4),
            Text(descricao!,
                style: TextStyle(fontSize: 12, color: c.textoSuave)),
          ],
        ],
      ),
    );
  }
}

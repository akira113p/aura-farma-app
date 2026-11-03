import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

// Proporção das colunas (Produto/Categoria/Estoque/Mín./Preço), igual ao Figma.
const _flexProduto = 34;
const _flexCategoria = 22;
const _flexEstoque = 14;
const _flexMinimo = 10;
const _flexPreco = 20;

/// Cabeçalho da tabela: Produto | Categoria | Estoque | Mín. | Preço.
class CabecalhoTabelaMedicamentos extends StatelessWidget {
  const CabecalhoTabelaMedicamentos({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    final estilo = TextStyle(fontSize: 12, color: c.textoSuave);
    Widget col(String t, int flex) => Expanded(
          flex: flex,
          child: Text(t,
              style: estilo, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
    // [ESCRITO À MÃO] colunas do DataTable original de estoque.dart (Produto/Categoria/Estoque/Preço)
    // — agora em Row+Expanded (sem scroll lateral) e com a coluna "Mín." do Figma
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(children: [
        col('Produto', _flexProduto),
        col('Categoria', _flexCategoria),
        col('Estoque', _flexEstoque),
        col('Mín.', _flexMinimo),
        col('Preço', _flexPreco),
      ]),
    );
    // [FIM ESCRITO À MÃO]
  }
}

/// Linha "nome+código | categoria | estoque | mín | preço" (estoque e scanner).
class LinhaMedicamento extends StatelessWidget {
  const LinhaMedicamento({super.key, required this.med, this.onTap});

  final Medicamentos med;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // [ESCRITO À MÃO] célula "Nome e Código empilhados" do DataTable original
            // (nome em cima, código cinza menor embaixo) — negrito trocado pelo peso do Figma
            Expanded(
              flex: _flexProduto,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: c.texto)),
                  Text(med.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: c.textoSuave)),
                ],
              ),
            ),
            // [FIM ESCRITO À MÃO]
            Expanded(
              flex: _flexCategoria,
              child: Text(med.categorias,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textoSuave)),
            ),
            Expanded(
              flex: _flexEstoque,
              child: Text('${med.quantidade}',
                  style: TextStyle(
                      fontSize: 13,
                      color: med.emBaixa ? c.perigo : c.sucesso)),
            ),
            Expanded(
              flex: _flexMinimo,
              child: Text('${med.minimo}',
                  style: TextStyle(fontSize: 12, color: c.textoFraco)),
            ),
            Expanded(
              flex: _flexPreco,
              child: Text(formatarPreco(med.preco),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.texto)),
            ),
          ],
        ),
      ),
    );
  }
}

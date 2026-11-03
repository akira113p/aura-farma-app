// O QUE É ESTE ARQUIVO
// Peças da "tabela" de medicamentos: o cabeçalho das colunas
// (`CabecalhoTabelaMedicamentos`) e cada linha de medicamento (`LinhaMedicamento`).
// Usado pelas telas de estoque e do scanner para listar produtos no mesmo formato.
// Usa o modelo `Medicamentos` (models.dart) e as cores do tema (theme/app_theme.dart).
// Não é uma tabela nativa do Flutter: é uma Row com colunas de largura proporcional.
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

// Proporção das colunas (Produto/Categoria/Estoque/Mín./Preço), igual ao Figma.
// São "pesos" de largura (flex): somam 100, então cada número é quase uma
// porcentagem do espaço da linha. O cabeçalho e as linhas usam os mesmos pesos
// para as colunas ficarem alinhadas.
const _flexProduto = 34;
const _flexCategoria = 22;
const _flexEstoque = 14;
const _flexMinimo = 10;
const _flexPreco = 20;

/// Cabeçalho da tabela: Produto | Categoria | Estoque | Mín. | Preço.
///
/// StatelessWidget: não guarda estado, só desenha os títulos fixos das colunas.
/// (veja GUIA_FLUTTER.md → StatelessWidget)
class CabecalhoTabelaMedicamentos extends StatelessWidget {
  const CabecalhoTabelaMedicamentos({super.key});

  /// Desenha uma linha com os títulos das 5 colunas. Chamado pelo Flutter
  /// sempre que a tela é desenhada.
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    // Estilo único (pequeno e cinza) reaproveitado em todos os títulos.
    final estilo = TextStyle(fontSize: 12, color: c.textoSuave);
    // Função local: cria uma coluna com texto [t] e peso de largura [flex].
    // `Expanded(flex: n)` reparte a largura da linha proporcionalmente aos pesos.
    // Texto limitado a 1 linha, com "..." se não couber.
    Widget col(String t, int flex) => Expanded(
          flex: flex,
          child: Text(t,
              style: estilo, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
    // [ESCRITO À MÃO] colunas do DataTable original de estoque.dart (Produto/Categoria/Estoque/Preço)
    // — agora em Row+Expanded (sem scroll lateral) e com a coluna "Mín." do Figma
    // Padding: pequena folga nas bordas; Row: coloca as colunas lado a lado.
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
///
/// StatelessWidget: mostra os dados de UM medicamento e avisa quando é tocada.
class LinhaMedicamento extends StatelessWidget {
  const LinhaMedicamento({super.key, required this.med, this.onTap});

  /// O medicamento que esta linha exibe (nome, código, quantidade, preço...).
  final Medicamentos med;

  /// Ação ao tocar na linha (ex.: abrir detalhes). Pode ser nula: aí a linha
  /// simplesmente não reage ao toque. `VoidCallback` = função sem parâmetros.
  final VoidCallback? onTap;

  /// Desenha a linha com as 5 colunas, usando os mesmos pesos do cabeçalho.
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    // InkWell: torna a linha tocável, com o efeito de "ondinha" do Material.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        // Row: as colunas lado a lado, centralizadas na vertical.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // [ESCRITO À MÃO] célula "Nome e Código empilhados" do DataTable original
            // (nome em cima, código cinza menor embaixo) — negrito trocado pelo peso do Figma
            // Coluna Produto: Column empilha nome (até 2 linhas) e código (1 linha).
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
            // Coluna Categoria.
            Expanded(
              flex: _flexCategoria,
              child: Text(med.categorias,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textoSuave)),
            ),
            // Coluna Estoque: vermelho (perigo) se o estoque está em baixa,
            // verde (sucesso) se está normal. `'${...}'` converte o número em texto.
            Expanded(
              flex: _flexEstoque,
              child: Text('${med.quantidade}',
                  style: TextStyle(
                      fontSize: 13,
                      color: med.emBaixa ? c.perigo : c.sucesso)),
            ),
            // Coluna Mín.: estoque mínimo desejado, em cor bem fraca.
            Expanded(
              flex: _flexMinimo,
              child: Text('${med.minimo}',
                  style: TextStyle(fontSize: 12, color: c.textoFraco)),
            ),
            // Coluna Preço: `formatarPreco` (de models.dart) transforma o número em texto de moeda.
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

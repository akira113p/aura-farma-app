// O QUE É ESTE ARQUIVO
// Catálogo de ícones do app. Em vez de espalhar nomes de ícones pelas telas,
// cada tela pede "Ico.busca", "Ico.estoque" etc. e a função `ico(...)` devolve o
// desenho certo. Assim, se um dia trocar a biblioteca de ícones, só este arquivo muda.
// Usado por quase todas as telas e widgets (cabecalho.dart, cartao.dart, barra de abas...).
// Usa o pacote `iconoir_flutter` (ícones em SVG, que são desenhos vetoriais).
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as ic;

/// Ícones do Figma. O design usa a família Iconoir (nós "cube", "system-restart", "list",
/// "bookmark", "scan-barcode", "search", "nav-arrow-down", "send-diagonal-solid",
/// "camera-solid"), então usamos o mesmo conjunto em vez do Material.
///
/// Um `enum` é uma lista fechada de opções com nome. Aqui cada opção é um ícone
/// que o app conhece; o comentário ao lado de cada uma diz qual desenho da
/// biblioteca Iconoir ela representa.
enum Ico {
  estoque, // cube
  assistente, // system-restart
  contagem, // list
  solicitados, // bookmark
  scanner, // scan-barcode
  busca, // search
  seta, // nav-arrow-down
  enviar, // send-diagonal-solid
  camera, // camera-solid
  lua, // half-moon
  sol, // sun-light
}

/// Desenha o ícone [i] com [size] e [color] (a cor precisa ser explícita: o SVG não herda do IconTheme).
///
/// Recebe: qual ícone ([i]), o tamanho em pixels ([size], padrão 24) e a cor
/// ([color], obrigatória). Devolve um widget (a "peça" de tela) pronto para
/// colocar dentro de outro widget. É chamada sempre que uma tela precisa mostrar
/// um ícone, por exemplo `ico(Ico.busca, color: c.textoSuave)`.
/// (veja GUIA_FLUTTER.md → Widget)
Widget ico(Ico i, {double size = 24, required Color color}) {
  // `switch` com `=>` (Dart 3): escolhe o resultado conforme o valor de `i`.
  // O Dart obriga a cobrir todas as opções do enum, então esquecer um ícone
  // novo aqui vira erro de compilação (bom para não esquecer).
  return switch (i) {
    Ico.estoque => ic.Cube(width: size, height: size, color: color),
    Ico.assistente => ic.SystemRestart(width: size, height: size, color: color),
    Ico.contagem => ic.List(width: size, height: size, color: color),
    Ico.solicitados => ic.Bookmark(width: size, height: size, color: color),
    Ico.scanner => ic.ScanBarcode(width: size, height: size, color: color),
    Ico.busca => ic.Search(width: size, height: size, color: color),
    Ico.seta => ic.NavArrowDown(width: size, height: size, color: color),
    Ico.enviar => ic.SendDiagonalSolid(width: size, height: size, color: color),
    Ico.camera => ic.CameraSolid(width: size, height: size, color: color),
    Ico.lua => ic.HalfMoon(width: size, height: size, color: color),
    Ico.sol => ic.SunLight(width: size, height: size, color: color),
  };
}

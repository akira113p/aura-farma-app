import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as ic;

/// Ícones do Figma. O design usa a família Iconoir (nós "cube", "system-restart", "list",
/// "bookmark", "scan-barcode", "search", "nav-arrow-down", "send-diagonal-solid",
/// "camera-solid"), então usamos o mesmo conjunto em vez do Material.
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
Widget ico(Ico i, {double size = 24, required Color color}) {
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

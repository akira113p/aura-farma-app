// O QUE É ESTE ARQUIVO: define as CORES e o TEMA (claro e escuro) do app inteiro.
// Fica na pasta `theme/` e é usado por praticamente todas as telas: elas pedem as
// cores com `AppCores.of(context)` em vez de escrever cores "no braço".
// O `main.dart` usa `temaClaro()` e `temaEscuro()` para configurar o MaterialApp.
// Assim, se o usuário troca de tema, todas as telas mudam juntas.
// (veja GUIA_FLUTTER.md → Tema e cores)
import 'package:flutter/material.dart';

/// Classe que guarda um "conjunto de cores" (uma paleta) com nomes em português.
/// Existem duas paletas prontas: `claro` e `escuro`.
/// `Color(0xFFRRGGBB)` é uma cor em hexadecimal: os 2 primeiros dígitos (FF) são a
/// opacidade (FF = totalmente visível) e os 6 seguintes são vermelho, verde e azul.
/// Paleta do app (medida nos frames do Figma + tokens do web).
class AppCores {
  // Campos: cada um é uma cor com um papel no app.
  // fundo = fundo da tela; superficie = cartões/caixas por cima do fundo;
  // borda = linhas de contorno; texto = texto principal; textoSuave = texto secundário;
  // textoFraco = dicas/placeholders; destaque = cor da marca (laranja);
  // destaqueSuave = laranja clarinho (ex.: bolha de mensagem do usuário);
  // sucesso = verde (ok); aviso = amarelo/marrom (atenção); perigo = vermelho (erro).
  final Color fundo,
      superficie,
      borda,
      texto,
      textoSuave,
      textoFraco,
      destaque,
      destaqueSuave,
      sucesso,
      aviso,
      perigo;

  // Construtor `const`: monta a paleta com todas as cores obrigatórias (`required`).
  // `const` significa que o objeto é criado já na compilação, o que economiza memória.
  const AppCores({
    required this.fundo,
    required this.superficie,
    required this.borda,
    required this.texto,
    required this.textoSuave,
    required this.textoFraco,
    required this.destaque,
    required this.destaqueSuave,
    required this.sucesso,
    required this.aviso,
    required this.perigo,
  });

  // Paleta do tema CLARO (fundo cinza-claro, cartões brancos, texto quase preto).
  // `static const` = pertence à classe (não precisa criar um objeto para usar).
  static const claro = AppCores(
      fundo: Color(0xFFEBE9EA),
      superficie: Color(0xFFFFFFFF),
      borda: Color(0xFF8A8A8A),
      texto: Color(0xFF0A0A0A),
      textoSuave: Color(0xFF737373),
      textoFraco: Color(0xFFA3A3A3),
      destaque: Color(0xFFF97316),
      destaqueSuave: Color(0xFFFDC9A0),
      sucesso: Color(0xFF15803D),
      aviso: Color(0xFFB45309),
      perigo: Color(0xFFB91C1C));

  // Paleta do tema ESCURO (fundo quase preto). A cor de destaque (laranja) é a mesma
  // nos dois temas para a marca ficar igual; as demais mudam para manter o contraste.
  static const escuro = AppCores(
      fundo: Color(0xFF0A0A0A),
      superficie: Color(0xFF131313),
      borda: Color(0xFF3A3A3A),
      texto: Color(0xFFFAFAFA),
      textoSuave: Color(0xFFA1A1A1),
      textoFraco: Color(0xFF6B6B6B),
      destaque: Color(0xFFF97316),
      destaqueSuave: Color(0xFF5A2A0A),
      sucesso: Color(0xFF4ADE80),
      aviso: Color(0xFFFBBF24),
      perigo: Color(0xFFF87171));

  /// Devolve a paleta do tema que está ativo agora.
  /// Recebe o `context` (o "endereço" do widget na árvore, usado para perguntar ao
  /// Theme que está acima qual é o brilho atual). Retorna `escuro` ou `claro`.
  /// Chamada dentro do `build` de quase toda tela, ex.: `final c = AppCores.of(context);`.
  /// Escolhe a paleta pela brightness do tema atual.
  static AppCores of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? escuro : claro;
}

/// Monta um `ThemeData` (o "pacote de estilo" do Material: cores, fontes, campos de
/// texto, diálogos...) a partir de uma paleta [c] e do brilho [b] (claro/escuro).
/// É privada (`_`) e só é usada pelas duas funções `temaClaro`/`temaEscuro` no fim.
/// Por que existe: evita repetir o mesmo código para os dois temas.
ThemeData _montar(AppCores c, Brightness b) {
  // (1) Cria um tema base com Material 3 (versão atual do visual do Android/Flutter).
  // `ColorScheme.fromSeed` gera um conjunto de cores a partir de uma "semente" (o
  // laranja); depois `.copyWith` troca só as cores que queremos controlar à mão.
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: c.fundo,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.destaque,
      brightness: b,
    ).copyWith(
      primary: c.destaque,
      onPrimary: Colors.white,
      surface: c.superficie,
      onSurface: c.texto,
      error: c.perigo,
    ),
  );
  // (2) Pega o tema base e sobrescreve detalhes (`copyWith` = cópia com alterações).
  // `textTheme.apply` pinta todos os textos padrão com a cor de texto da nossa paleta.
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.texto, displayColor: c.texto),
    dividerColor: c.borda,
    cardColor: c.superficie,
    canvasColor: c.superficie,
    dialogTheme: DialogThemeData(backgroundColor: c.superficie),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.superficie),
    // (3) Aparência padrão dos campos de texto (TextField): fundo preenchido, dica
    // (hint) em cinza fraco, e borda arredondada (raio 10) que fica laranja quando o
    // campo está em foco (usuário digitando).
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficie,
      hintStyle: TextStyle(color: c.textoFraco, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.destaque),
      ),
    ),
  );
}

/// Tema claro pronto para entregar ao MaterialApp (`theme:` no main.dart).
/// Sintaxe `=>` é uma função de uma linha só: devolve o resultado da expressão.
ThemeData temaClaro() => _montar(AppCores.claro, Brightness.light);
/// Tema escuro pronto (`darkTheme:` no main.dart); o Flutter escolhe entre os dois
/// conforme a configuração do celular ou do app.
ThemeData temaEscuro() => _montar(AppCores.escuro, Brightness.dark);

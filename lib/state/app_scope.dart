// O QUE É ESTE ARQUIVO
// Disponibiliza o AppStore (estado global) para toda a árvore de widgets.
// Quem usa: main.dart o coloca no topo; todas as telas leem com `AppScope.of(context)`
// (redesenha ao mudar) ou `AppScope.read(context)` (só lê). Usa: state/app_store.dart.

import 'package:flutter/widgets.dart';

import 'app_store.dart';

/// Expõe o [AppStore] na árvore de widgets.
///
/// É um InheritedNotifier: um widget que fica no topo da árvore e deixa qualquer widget
/// abaixo dele "pegar" o AppStore, sem precisar passar de mão em mão por construtores.
/// Além disso, quando o AppStore chama `notifyListeners`, os widgets que o leram com
/// `of` são redesenhados automaticamente. Veja GUIA_FLUTTER.md → Estado compartilhado.
class AppScope extends InheritedNotifier<AppStore> {
  /// Recebe o `store` (guardado como `notifier`) e o `child` (o resto do app, abaixo dele).
  const AppScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// Rebuilda o widget quando o store muda.
  // Usar dentro do `build`: a tela passa a depender do store e é redesenhada quando ele muda.
  static AppStore of(BuildContext context) {
    // Sobe a árvore a partir de `context` procurando o AppScope e registra a dependência.
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    // `assert` só vale em modo debug: avisa cedo se esqueceram de pôr o AppScope no topo.
    assert(s != null, 'AppScope não encontrado na árvore');
    // `!` = "tenho certeza de que não é nulo".
    return s!.notifier!;
  }

  /// Não rebuilda (para callbacks).
  // Usar em ações (toque de botão, initState): lê o store sem se inscrever nas mudanças.
  static AppStore read(BuildContext context) {
    // Igual ao anterior, mas SEM registrar dependência (por isso não redesenha).
    final s = context.getInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope não encontrado na árvore');
    return s!.notifier!;
  }
}

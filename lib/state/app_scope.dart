import 'package:flutter/widgets.dart';

import 'app_store.dart';

/// Expõe o [AppStore] na árvore de widgets.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// Rebuilda o widget quando o store muda.
  static AppStore of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope não encontrado na árvore');
    return s!.notifier!;
  }

  /// Não rebuilda (para callbacks).
  static AppStore read(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope não encontrado na árvore');
    return s!.notifier!;
  }
}

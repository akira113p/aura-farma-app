// O QUE É ESTE ARQUIVO
// Testa a tela de Estoque (TelaEstoque): a lista de medicamentos e o campo de busca.
// Como rodar:  flutter test test/estoque_test.dart
// Precisa de: nada (sem backend, sem internet, sem celular). A tela é montada na memória.
// Passou = a tela lista os produtos e a busca filtra (ignorando acento/maiúsculas). Falhou = a tela ou a busca quebrou.
// Veja a seção 'Testes' do GUIA_FLUTTER.md.
//
import 'package:aurafarma_app/estoque.dart';
import 'package:aurafarma_app/models.dart';
import 'package:aurafarma_app/state/app_scope.dart';
import 'package:aurafarma_app/state/app_store.dart';
import 'package:aurafarma_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // CENÁRIO: uma loja com 2 medicamentos (Dipirona e Amoxicilina) já carregados, sem precisar de login.
  // AÇÃO: mostra a TelaEstoque e digita 'amox' na busca.
  // CONFERIDO: antes da busca aparecem os 2 produtos e o contador '2 medicamento(s)'; depois só a Amoxicilina fica.
  // 'testWidgets' monta uma tela de verdade na memória (sem celular) e deixa a gente 'mexer' nela; 'tester' é o
  // controle remoto dessa tela de teste.
  testWidgets('TelaEstoque lista produtos e filtra pela busca', (tester) async {
    // AppStore é o 'cérebro' do app (guarda usuário e dados). Aqui preenchemos o estado à mão,
    // em vez de buscar no servidor.
    final store = AppStore()
      ..estado = Estado(
        populado: true,
        produtos: [
          Medicamentos(
              id: '1', nome: 'Dipirona', codigo: '111', categorias: 'Analgésico',
              quantidade: 5, preco: 10, minimo: 2),
          Medicamentos(
              id: '2', nome: 'Amoxicilina', codigo: '222', categorias: 'Antibiótico',
              quantidade: 1, preco: 20, minimo: 3),
        ],
        solicitacoes: const [],
        contagens: const [],
      );

    // pumpWidget desenha o widget (a tela) pela primeira vez.
    // AppScope entrega o AppStore às telas filhas; o MaterialApp com tema é necessário porque a tela usa botões, textos e cores do Material.
    await tester.pumpWidget(AppScope(
      store: store,
      child: MaterialApp(
        theme: temaClaro(),
        home: const TelaEstoque(),
      ),
    ));

    // 'find' procura coisas na tela; 'findsOneWidget' exige que exista exatamente uma. Confere o contador e os dois nomes.
    expect(find.text('2 medicamento(s) no estoque'), findsOneWidget);
    expect(find.text('Dipirona'), findsOneWidget);
    expect(find.text('Amoxicilina'), findsOneWidget);

    // enterText digita 'amox' no campo de busca (o único TextField da tela).
    // pump() redesenha a tela uma vez, para a lista refletir o texto digitado.
    await tester.enterText(find.byType(TextField), 'amox');
    await tester.pump();
    // findsNothing = a Dipirona sumiu da lista; a Amoxicilina continua (a busca acha 'amox' dentro de 'Amoxicilina').
    expect(find.text('Dipirona'), findsNothing);
    expect(find.text('Amoxicilina'), findsOneWidget);
  });
}

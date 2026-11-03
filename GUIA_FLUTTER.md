# Guia de Flutter para quem está começando

Este guia explica, em português simples, os conceitos que aparecem no código deste app.
Os comentários dentro dos arquivos `.dart` apontam para cá (ex.: "veja GUIA_FLUTTER.md → StatefulWidget").

Se você só quer ter uma ideia geral: **uma tela do Flutter é uma árvore de "widgets"** (peças de LEGO).
Cada peça descreve um pedaço da tela (um texto, um botão, uma coluna). Quando os dados mudam, o Flutter
redesenha as peças afetadas.

---

## 1. Widget

Tudo o que aparece na tela é um **widget**: `Text`, `Icon`, `Container`, `Column`, a tela inteira…
Widgets se encaixam uns dentro dos outros, formando uma **árvore**:

```
Scaffold                 ← a "página" (fundo, barra de baixo...)
 └─ Column               ← empilha filhos na vertical
     ├─ Text("Estoque")
     └─ Expanded         ← ocupa o espaço que sobrar
         └─ ListView     ← lista rolável
```

Widgets de **layout** (organizam):
- `Column` (vertical) e `Row` (horizontal): colocam os filhos em fila. `children: [ ... ]` é a lista de filhos.
- `Expanded` / `Flexible`: dentro de Column/Row, dizem "ocupe o espaço que sobrar". `flex: 3` = peso 3 de espaço.
- `Padding`: afasta o filho das bordas. `EdgeInsets.all(8)` = 8 pixels de folga em volta.
- `SizedBox`: uma caixa de tamanho fixo; muito usada só para dar espaço (`SizedBox(height: 12)`).
- `Container`: caixa com cor, borda, cantos arredondados (`BoxDecoration`), tamanho e padding.
- `Stack`: empilha filhos **uns sobre os outros** (como camadas). `Positioned` põe um filho num ponto exato.
- `SingleChildScrollView` / `ListView`: deixam o conteúdo **rolar**. `ListView.builder` só desenha os itens visíveis (bom para listas grandes).
- `Center`, `Align`: posicionam o filho no centro / num canto.
- `SafeArea`: evita que o conteúdo fique embaixo do "notch" ou da barra de status do celular.
- `Scaffold`: o esqueleto de uma tela (corpo `body`, `appBar`, `bottomNavigationBar`, botão flutuante).

## 2. StatelessWidget × StatefulWidget

- **StatelessWidget** ("sem estado"): desenha algo que depende só do que recebeu no construtor. Não muda sozinho.
  Tem um método `build(context)` que devolve a árvore de widgets.
- **StatefulWidget** ("com estado"): precisa **lembrar de coisas que mudam** (o texto digitado, a aba escolhida…).
  São sempre **duas classes**: o widget (`TelaEstoque`) e o seu `State` (`_TelaEstoque`). As variáveis que mudam
  ficam no `State`.

### `setState`
Quando você muda uma variável do `State`, o Flutter **não sabe** que a tela precisa ser redesenhada.
Você avisa com `setState(() { minhaVariavel = novoValor; });`. Isso chama o `build` de novo.

### Ciclo de vida do State (em ordem)
- `initState()`: roda **uma vez** quando a tela nasce (bom para carregar dados).
- `didChangeDependencies()`: roda depois do `initState` e **de novo** quando algo de que a tela depende (como o tema, ou um `InheritedWidget`) muda.
- `build()`: roda **toda vez** que a tela precisa ser desenhada.
- `dispose()`: roda **uma vez** quando a tela morre. Aqui você libera o que criou (controllers, animações), senão vaza memória.
- `mounted`: `true` enquanto a tela ainda existe. Depois de um `await`, a tela pode já ter sido fechada;
  por isso o código checa `if (!mounted) return;` antes de usar `setState` ou `context`.

## 3. BuildContext (`context`)

Todo `build(BuildContext context)` recebe um `context`: é "o endereço deste widget na árvore".
Serve para **perguntar coisas aos widgets acima**: `Theme.of(context)` (cores/fontes), `MediaQuery.sizeOf(context)`
(tamanho da tela), `Navigator.of(context)` (abrir/fechar telas), `ScaffoldMessenger.of(context)` (mostrar SnackBar).

## 4. Dart essencial

- **`final`**: variável que recebe valor uma vez e não muda. **`const`**: valor fixo já na compilação (mais leve).
- **Null safety**: um tipo com `?` (ex.: `String?`) **pode ser nulo**; sem `?` nunca é nulo.
  - `x ?? 'padrão'`: usa `x`, ou `'padrão'` se `x` for nulo.
  - `x?.length`: só acessa se `x` não for nulo (senão dá nulo).
  - `x!`: "tenho certeza de que não é nulo" (cuidado: trava se for).
- **Parâmetros nomeados**: `Botao(texto: 'oi', onPressed: ...)`. `required` = obrigatório. Os que não têm são opcionais.
- **`async` / `await` / `Future`**: operações demoradas (internet, disco) devolvem um `Future` (uma "promessa de resultado").
  `await` espera o resultado **sem travar a tela**. Só se usa `await` dentro de uma função marcada `async`.
- **`try / catch / finally`**: `try` tenta; `catch` trata erro; `finally` roda sempre (com ou sem erro).
- **`List`** `[1, 2]`, **`Map`** `{'chave': valor}`, **`Set`** (sem repetidos).
  - `lista.map((x) => ...).toList()` transforma cada item; `lista.where((x) => condição)` filtra.
  - `for (final x in lista) Widget(...)` dentro de `children: [...]` cria um widget por item.
- **Interpolação**: `'Olá $nome'` ou `'Total: ${a + b}'`.
- **Funções-seta**: `(x) => x * 2` é uma função curta que devolve `x * 2`.
- **Records e `switch` com `=>`** (Dart 3): `(Color a, Color b) = ...` guarda dois valores juntos;
  `switch (tom) { A => ..., B => ... }` escolhe um valor conforme o caso.
- **`_nome`** (com sublinhado) = **privado** ao arquivo.

## 5. Estado compartilhado: ChangeNotifier + InheritedNotifier

`setState` só serve para dados de **uma** tela. Dados que várias telas usam (usuário logado, lista de produtos)
ficam num objeto de **estado global**: o `AppStore`.

- **`ChangeNotifier`**: classe com o método `notifyListeners()`. Quem estiver "escutando" é avisado de que algo mudou.
- **`AppScope`** (um `InheritedNotifier`): "pendura" o `AppStore` no topo da árvore para qualquer tela acessar com
  `AppScope.of(context)`. Duas formas de ler:
  - `AppScope.of(context)`: lê **e a tela se redesenha** quando o `AppStore` muda (use dentro do `build`).
  - `AppScope.read(context)`: só lê, **não** redesenha (use em ações, como ao tocar num botão).
- Fluxo típico: o usuário toca num botão → a tela chama um método do `AppStore` → ele fala com a API → atualiza
  seus dados e chama `notifyListeners()` → as telas que usam `AppScope.of(context)` se redesenham sozinhas.

## 6. Controllers e Focus

- **`TextEditingController`**: "controle remoto" de um `TextField`: lê (`.text`) e limpa (`.clear()`) o texto.
  Precisa de `dispose()`.
- **`ScrollController`**: lê/controla a posição da rolagem (ex.: rolar até o fim).
- **`AnimationController`**: motor de uma animação (vai de 0 a 1 ao longo do tempo).
  Precisa de `SingleTickerProviderStateMixin` no State e de `dispose()`.
- **`FocusManager.instance.primaryFocus?.unfocus()`**: tira o foco do campo (fecha o teclado).

## 7. Interação e feedback

- Botões: `onPressed: () { ... }` é o que acontece ao tocar; `onPressed: null` **desabilita** o botão.
- `InkWell`: deixa qualquer widget "tocável" com efeito de ondinha. `onTap` é o toque.
- `showDialog` abre uma caixinha de diálogo e devolve (com `await`) o que o usuário escolheu.
- `showModalBottomSheet` abre uma folha que sobe de baixo da tela.
- `SnackBar`: aviso rápido embaixo, mostrado com `ScaffoldMessenger.of(context).showSnackBar(...)`.
- `RefreshIndicator`: puxar a lista para baixo para atualizar.
- `Dismissible`: deslizar um item para o lado (apagar).
- `IndexedStack`: mantém **todas** as telas montadas, mas mostra só uma (é o que a barra de abas usa, por isso uma
  tela "escondida" continua viva em segundo plano).

## 8. Tema e cores

O app tem 2 temas (claro/escuro). A classe `AppCores` guarda as cores de cada um e `AppCores.of(context)` devolve
as do tema atual. Assim nenhuma tela escreve cor "no braço": se o usuário troca o tema, tudo muda junto.

## 9. Desenho livre: CustomPainter

Para desenhos que não existem como widget (a mira do scanner) usa-se `CustomPaint` + um `CustomPainter`,
cujo método `paint(canvas, size)` desenha linhas, retângulos etc. direto numa "tela em branco" (`Canvas`).

## 10. Rede: HTTP, JSON, cookie

- **HTTP**: o app pede coisas ao servidor (`GET` lê, `POST` cria/envia, `PATCH` altera, `DELETE` apaga).
- **JSON**: formato de texto em que os dados viajam (`{"name": "Dipirona", "stock": 42}`).
  `jsonDecode` transforma o texto em `Map`/`List`; `jsonEncode` faz o contrário.
  As classes do app têm `fromJson` para converter esse `Map` em objetos (`Medicamentos`, `Solicitacao`...).
- **Cookie de sessão (`sid`)**: depois do login o servidor manda um "crachá" (cookie). O app guarda o crachá e o envia
  em toda requisição, assim o servidor sabe quem você é sem pedir a senha de novo.

## 11. Testes

- `test(...)`: teste de uma função comum. `expect(valor, esperado)` confere o resultado.
- `testWidgets(...)`: monta uma tela de verdade **na memória** (sem celular), "toca" nela e confere o que apareceu.
- **Golden** (`matchesGoldenFile`): tira uma "foto" da tela e salva em PNG; nos testes visuais usamos isso
  para gerar as imagens do README.
- `flutter analyze` procura erros e avisos no código; `flutter test` roda os testes.

## 12. Comandos do dia a dia

```bash
flutter pub get        # baixa as dependências do pubspec.yaml
flutter run            # roda o app (r = recarrega rápido, R = reinicia)
flutter analyze        # confere o código
flutter test           # roda os testes
```
O arquivo `pubspec.yaml` lista as bibliotecas usadas (`http`, `mobile_scanner`, `shared_preferences`...).

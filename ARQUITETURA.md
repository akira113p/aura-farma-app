# auraFarma — app celular (Flutter): arquitetura

App mobile da farmácia. **Não tem banco próprio**: é mais um cliente do mesmo backend
do auraFarma web (`prototipo/backend`, Express + MongoDB). Web e celular leem/escrevem
os mesmos dados pela mesma API, escopados pelo usuário logado.

Fonte do visual: Figma `Untitled` (fileKey `70YEHFdzAg5WXZ52QaZ95x`), frames
`Android Compact - Home` e `- 6..9` (versão mais nova: barra inferior com 5 ícones
grandes, sem o logo "f") — 412×917. As variantes `.2` são o tema escuro.

## Convenção de comentários (obrigatória)

O código que já existia em `lib/` foi escrito à mão e é a **estrutura base**. Todo trecho
mantido/adaptado dele leva o marcador:

```dart
// [ESCRITO À MÃO] <o que era / o que mudou>
...código original (ou adaptado)...
// [FIM ESCRITO À MÃO]
```

Se o trecho foi adaptado, diga o que mudou na linha do marcador
(ex.: `// [ESCRITO À MÃO] filtro original de nome/código — agora também filtra categoria`).
Código novo não precisa de marcador. Comentários em pt-BR.

O que é escrito à mão hoje (preservar a ideia/nomes):
- `main.dart`: `MainApp`, `TelaInicial` com `IndexedStack` + `BottomNavigationBar` de 5 abas
  na ordem estoque, assistente IA, contagem, solicitados, scanner; método `MudardeTela`;
  classe `Medicamentos` (nome, codigo, categorias, quantidade, preco).
- `estoque.dart`: `TelaEstoque`, `filtrarEstoque` (busca por nome OU código, case-insensitive),
  `ListaFiltrada`, tabela Produto/Categoria/Estoque/Preço com nome+código empilhados.
- `assistente.dart`, `contagem.dart`, `solicitados.dart`, `scanner.dart`: só o esqueleto
  `StatefulWidget` + `Scaffold` + `AppBar(title)`. Manter os nomes `TelaX`/`_TelaX`.

## Pastas

```
lib/
  main.dart                 # [ESCRITO À MÃO] base: MainApp, TelaInicial (nav) — agora com AuthGate + tema
  config.dart               # URL da API (--dart-define)
  models.dart               # Medicamentos (escrito à mão, estendido) + Solicitacao, Contagem, Ajuste, Usuario, Estado
  core/
    api_client.dart         # HTTP + cookie de sessão 'sid' + ApiException
    sessao_storage.dart     # guarda o cookie no flutter_secure_storage
  state/
    app_store.dart          # ChangeNotifier: usuário, estado, ações (chamam a API)
    app_scope.dart          # InheritedNotifier p/ acessar o AppStore na árvore
  theme/
    app_theme.dart          # cores (claro/escuro) + ThemeData
  widgets/
    cabecalho.dart          # "Título / subtítulo" + descrição + botão de tema (lua)
    cartao.dart             # CartaoComFaixa (faixa laranja "Título  n algo") + Vazio + Selo (badge)
  login.dart                # tela de login (não existe no Figma; segue o mesmo visual)
  estoque.dart              # [ESCRITO À MÃO] base
  assistente.dart           # [ESCRITO À MÃO] base (esqueleto)
  contagem.dart             # [ESCRITO À MÃO] base (esqueleto)
  solicitados.dart          # [ESCRITO À MÃO] base (esqueleto)
  scanner.dart              # [ESCRITO À MÃO] base (esqueleto)
test/
  models_test.dart          # parse JSON + filtro do estoque
```

Sem `provider`/`riverpod`: estado com `ChangeNotifier` + `InheritedNotifier` (nativos do Flutter).

## Dependências (pubspec)

- `http` — chamadas à API.
- `flutter_secure_storage` — guarda o cookie de sessão.
- `shared_preferences` — tema (claro/escuro) e histórico do assistente IA.
- `mobile_scanner` — câmera/código de barras (só Android/iOS; em outras plataformas a tela
  usa digitação manual do código).

Android (`android/app/src/main/AndroidManifest.xml`): `INTERNET` e `CAMERA` permissions,
`android:usesCleartextTraffic="true"` (dev em http). `android:label="auraFarma"`.

## Integração com o backend

### Config (`config.dart`)
```dart
class AppConfig {
  // flutter run --dart-define=API_BASE_URL=http://192.168.0.10:4000/api
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  /// Se vazio: Android emulador → http://10.0.2.2:4000/api ; resto → http://localhost:4000/api
  static String get baseUrl;
}
```

### Autenticação (sem mudar o backend)
O backend usa sessão `express-session` com cookie **`sid`** (httpOnly vale só p/ navegador;
num app nativo o cookie é um header comum). Fluxo:
1. `POST /auth/login` `{identifier, password}` → `200 {user}` + header `set-cookie: sid=...`.
2. `ApiClient` lê `set-cookie`, extrai só `sid=<valor>` e salva via `SessaoStorage`.
3. Toda requisição manda `Cookie: sid=<valor>`. Sempre que vier um novo `set-cookie` com `sid`, atualizar.
4. Ao abrir o app: se tem cookie salvo → `GET /auth/me` → `200 {user}` entra; `401` → apaga cookie, mostra login.
5. Qualquer `401` em outra rota → `AppStore` faz logout local (apaga cookie, volta ao login).
6. Logout: `POST /auth/logout` (ignora erro) + apaga cookie.

Google login fica fora (no web usa Google Identity Services; no app exigiria `google_sign_in`
+ client id Android). O botão não aparece no app.

### Erros
Backend responde erro como `{ "error": "mensagem", "details": {campo: msg}? }`.
```dart
class ApiException implements Exception {
  final int status;            // 0 = sem conexão
  final String message;        // 'error' do backend, ou 'Sem conexão com o servidor.'
  final Map<String, String> details;
}
```
Timeout de 20 s (IA: 60 s). Erro de rede → `ApiException(0, 'Sem conexão com o servidor.')`.

### `ApiClient` (core/api_client.dart)
```dart
class ApiClient {
  ApiClient({http.Client? client, SessaoStorage? storage});
  Future<void> carregarSessao();                       // lê cookie salvo p/ memória
  bool get temSessao;
  Future<dynamic> get(String path, {Duration? timeout});
  // timeout posicional: Dart não mistura [opcional posicional] com {nomeado}.
  // IA: api.post('/ia/ask', body, const Duration(seconds: 60))
  Future<dynamic> post(String path, [Object? body, Duration? timeout]);
  Future<dynamic> patch(String path, Object body);
  Future<void> delete(String path);
  Future<void> limparSessao();
}
```
`path` é relativo a `baseUrl` (ex.: `'/estado'`). Corpo JSON, `Content-Type: application/json`.
Respostas `204` → `null`. Status >= 400 → `ApiException`.

### Endpoints usados (todos exigem sessão, exceto login)

| Ação | Rota | Corpo | Resposta |
|---|---|---|---|
| login | `POST /auth/login` | `{identifier, password}` | `{user}` |
| sessão | `GET /auth/me` | — | `{user}` |
| sair | `POST /auth/logout` | — | 204 |
| carregar tudo | `GET /estado` | — | `{populated, products[], sales[], requests[], counts[], activity[]}` |
| popular exemplo | `POST /estado/seed` | — | mesmo de `/estado` |
| solicitação nova/+1 | `POST /solicitados` | `{name, note}` | `{request}` (se o nome já existe, soma +1) |
| editar solicitação | `PATCH /solicitados/:id` | `{count?, note?}` | `{request}` |
| apagar solicitação | `DELETE /solicitados/:id` | — | 204 |
| aplicar contagem | `POST /contagem` | `{adjustments:[{pid, newStock}]}` | `{count, updatedProducts[]}` |
| IA | `POST /ia/ask` | `{messages:[{role:'user'|'assistant', content}], escopo:'todos'}` | `{reply, titulo, consultou[]}` |
| IA ligada? | `GET /ia/config` | — | `{enabled}` |

Limites do backend: `messages` 1..20 itens, `content` ≤ 4000 chars; escrita 120/min; IA 20/min.

### Formatos JSON (nomes longos, como a API devolve)
- user: `{id, username, pharmacyName, email, authProviders[]}`
- product: `{id, sku, name, cat, price, cost, stock, min, validade?, principioAtivo?, tags?}`
- request: `{id, name, note, count, date}` (`date` = `"YYYY-MM-DD"`)
- count: `{id, ts (ISO), adjustments:[{pid, newStock, diff}], total}`

## Modelos (`models.dart`)

```dart
// [ESCRITO À MÃO] classe original — estendida com id, minimo, custo e fromJson
class Medicamentos {
  final String id;          // novo
  final String nome;        // json 'name'
  final String codigo;      // json 'sku' (código de barras/EAN)
  final String categorias;  // json 'cat'
  final int quantidade;     // json 'stock'
  final double preco;       // json 'price'
  final int minimo;         // novo, json 'min'
  final double custo;       // novo, json 'cost'
  bool get emBaixa => quantidade <= minimo;
  factory Medicamentos.fromJson(Map<String, dynamic> j);
  Medicamentos copyWith({int? quantidade});
}
class Usuario { id, username, pharmacyName, email; fromJson }
class Solicitacao { id, nome('name'), nota('note'), pedidos('count'), data('date' String YYYY-MM-DD); fromJson }
class AjusteContagem { pid, novoEstoque('newStock'), diferenca('diff'); fromJson }
class Contagem { id, quando (DateTime de 'ts', toLocal), ajustes List<AjusteContagem>; int get diferencaTotal; fromJson }
class Estado {
  final bool populado; final List<Medicamentos> produtos; final List<Solicitacao> solicitacoes;
  final List<Contagem> contagens;
  factory Estado.fromJson(Map<String, dynamic> j);  // ignora sales/activity
  static const vazio = ...;
  Estado copyWith({...});
}
```
`num` do JSON → usar `(j['price'] as num).toDouble()` / `(j['stock'] as num).toInt()`.

### Funções puras (em models.dart, testáveis)
```dart
/// [ESCRITO À MÃO] lógica do filtrarEstoque original (nome OU código), extraída p/ reusar
List<Medicamentos> filtrarMedicamentos(List<Medicamentos> lista, String texto, {String? categoria});
String formatarPreco(double v);      // 'R$ 12,50'  (vírgula decimal, sem intl)
String formatarData(DateTime d);     // 'dd/mm/aaaa'
String formatarDataIso(String ymd);  // 'YYYY-MM-DD' -> 'dd/mm/aaaa'
String formatarDataHora(DateTime d); // 'dd/mm/aaaa hh:mm'
```
Busca: case-insensitive e **sem acento** (normalizar á/à/â/ã/é/ê/í/ó/ô/õ/ú/ç).

## Estado global (`state/app_store.dart`)

```dart
enum StatusAuth { carregando, deslogado, logado }

class AppStore extends ChangeNotifier {
  AppStore({ApiClient? api});
  final ApiClient api;

  StatusAuth status;          // começa em carregando
  Usuario? usuario;
  Estado estado;              // Estado.vazio até carregar
  bool carregandoEstado;
  String? erroEstado;         // mensagem p/ mostrar com botão "tentar de novo"
  ThemeMode tema;             // claro/escuro, persistido em shared_preferences ('aurafarma.tema')

  Future<void> iniciar();                              // carrega tema + cookie → /auth/me → recarregar()
  Future<void> entrar(String identificador, String senha); // lança ApiException
  Future<void> sair();
  Future<void> recarregar();                           // GET /estado
  Future<void> popularExemplo();                       // POST /estado/seed
  void alternarTema();

  // Solicitados
  Future<void> registrarSolicitacao(String nome, String nota);
  Future<void> somarSolicitacao(Solicitacao s);        // PATCH count: s.pedidos + 1
  Future<void> removerSolicitacao(String id);

  // Contagem
  Future<void> aplicarContagem(Map<String, int> novoEstoquePorPid); // POST /contagem; atualiza produtos + insere contagem no topo

  // Scanner
  Medicamentos? buscarPorCodigo(String codigo);       // procura em estado.produtos por codigo exato (trim)
}
```
Regras: toda ação de escrita atualiza `estado` com a resposta do servidor (sem recarregar tudo)
e chama `notifyListeners()`. Erros sobem como `ApiException`; `401` → `_deslogarLocal()`.
Telas mostram erro com `ScaffoldMessenger.showSnackBar(SnackBar(content: Text(e.message)))`.

`state/app_scope.dart`:
```dart
class AppScope extends InheritedNotifier<AppStore> {
  static AppStore of(BuildContext context);  // dependOnInheritedWidgetOfExactType (rebuilda)
  static AppStore read(BuildContext context); // getInheritedWidgetOfExactType (não rebuilda; p/ callbacks)
}
```

## Tema (`theme/app_theme.dart`)

Medido nos frames do Figma + tokens do web (`frontend/src/index.css`).

```dart
class AppCores {
  final Color fundo, superficie, borda, texto, textoSuave, textoFraco,
      destaque, destaqueSuave, sucesso, aviso, perigo;
  static const claro = AppCores(
    fundo: Color(0xFFEBE9EA), superficie: Color(0xFFFFFFFF), borda: Color(0xFF8A8A8A),
    texto: Color(0xFF0A0A0A), textoSuave: Color(0xFF737373), textoFraco: Color(0xFFA3A3A3),
    destaque: Color(0xFFF97316), destaqueSuave: Color(0xFFFDC9A0),
    sucesso: Color(0xFF15803D), aviso: Color(0xFFB45309), perigo: Color(0xFFB91C1C));
  static const escuro = AppCores(
    fundo: Color(0xFF0A0A0A), superficie: Color(0xFF131313), borda: Color(0xFF3A3A3A),
    texto: Color(0xFFFAFAFA), textoSuave: Color(0xFFA1A1A1), textoFraco: Color(0xFF6B6B6B),
    destaque: Color(0xFFF97316), destaqueSuave: Color(0xFF5A2A0A),
    sucesso: Color(0xFF4ADE80), aviso: Color(0xFFFBBF24), perigo: Color(0xFFF87171));
  static AppCores of(BuildContext context); // pelo Theme.of(context).brightness
}
ThemeData temaClaro(); ThemeData temaEscuro();  // useMaterial3, scaffoldBackgroundColor = fundo, colorScheme.primary = destaque
```
Laranja da marca = `#F97316` (o mesmo `--accent` do web; o `Color(169,65,25)` do main original vira este).
Raio: campos 10, cartões 12, botão laranja 12, selo (badge) 999.
Tipografia: título de tela 18 regular (cor texto) + " / subtítulo" 15 (textoSuave);
descrição 12 (textoSuave); corpo 14; legenda 11.

## Componentes compartilhados

`widgets/cabecalho.dart`:
```dart
class Cabecalho extends StatelessWidget {
  const Cabecalho({required this.titulo, required this.subtitulo, this.descricao, this.acoes});
  // Linha 1: "Estoque" + " / Medicamentos e quantidades"  (RichText) + à direita botão lua/sol (AppScope.read(context).alternarTema())
  // Linha 2: descricao (12, textoSuave)
  // padding: fromLTRB(22, 16, 22, 12). Usar dentro de SafeArea.
}
```
`widgets/cartao.dart`:
```dart
class CartaoComFaixa extends StatelessWidget { // "Contagens anteriores  0 realizada(s)" / "Histórico  0 pergunta(s)"
  const CartaoComFaixa({required this.titulo, required this.contador, required this.child});
  // faixa laranja (destaque) altura ~36, título texto escuro 13 + contador branco 12; corpo superficie, borda 1px borda
}
class Vazio extends StatelessWidget { const Vazio({required this.icone, required this.texto}); } // ícone num quadrado cinza arredondado + texto suave
class Selo extends StatelessWidget { const Selo(this.texto, {this.tom = TomSelo.destaque}); } // pílula: destaqueSuave + texto destaque bold 12
enum TomSelo { destaque, sucesso, aviso, neutro }
class BotaoLaranja extends StatelessWidget { const BotaoLaranja({required this.texto, this.icone, required this.onPressed, this.carregando = false}); }
```

## Navegação (`main.dart`)

```
MainApp (MaterialApp: theme/darkTheme/themeMode do AppStore; debugShowCheckedModeBanner:false)
 └─ AppScope(notifier: store)
     └─ AuthGate
          carregando → splash (logo "f" laranja + CircularProgressIndicator)
          deslogado  → TelaLogin
          logado     → TelaInicial  [ESCRITO À MÃO]
```
`TelaInicial` mantém `IndexedStack` + `BottomNavigationBar` (ordem/labels do Figma, minúsculas):
`estoque` (Icons.inventory_2_outlined), `assistente IA` (Icons.auto_awesome_outlined),
`contagem` (Icons.format_list_bulleted), `solicitados` (Icons.bookmark_border /
selecionado Icons.bookmark), `scanner` (Icons.qr_code_scanner). Barra branca (superficie),
borda superior 1px, ícones 30, selecionado = texto (preto/branco) e não-selecionado = textoSuave
(no Figma o ativo é preto, não laranja), labels 12.

## Telas

### Login (`login.dart`) — não existe no Figma
Fundo `fundo`. Centro: quadrado laranja 64×64 raio 14 com "f" branco bold 36; "auraFarma" 24 bold;
"Entre na sua conta" textoSuave. Campos (superficie, raio 10, borda 1px): "E-mail ou usuário",
"Senha" (obscure + olho). `BotaoLaranja('Entrar')` com loading. Erro do backend embaixo em `perigo`.
Rodapé pequeno: "Use a mesma conta do auraFarma web." + o `AppConfig.baseUrl` em textoFraco 11
(ajuda a depurar IP). Enter no campo senha envia.

### Estoque (`estoque.dart`) — frame Home
- `Cabecalho('Estoque', 'Medicamentos e quantidades', descricao: '<n> medicamento(s) no estoque')`.
- Linha com 2 campos lado a lado (gap 11, altura 37, raio 10, borda 1px, superficie):
  busca (ícone lupa, hint "buscar por nome, código") flex 190 | dropdown "todas as categorias" flex 154
  (categorias = distintas de `estado.produtos`, ordenadas).
- Tabela em cartão (superficie, borda 1px): cabeçalho `Produto | Categoria | Estoque | Mín. | Preço`
  (12, textoSuave). Linhas separadas por divisória 1px: nome (14) + código (10, textoSuave) empilhados
  [ESCRITO À MÃO]; categoria (textoSuave); estoque em `sucesso` (ou `perigo` se `emBaixa`);
  mín. (textoFraco); preço (`formatarPreco`). Usar `ListView` com linhas `Row` + `Expanded(flex)`
  (não `DataTable`: no Figma a tabela cabe na largura, sem scroll lateral). flex: 34/22/14/10/20.
- `RefreshIndicator` → `store.recarregar()`.
- Estados: carregando → spinner; erro → texto + "tentar de novo"; `!populado` → `Vazio` +
  `BotaoLaranja('popular com exemplos')` → `store.popularExemplo()`; filtro sem resultado → "Nenhum produto encontrado".
- Toque numa linha → bottom sheet com detalhes (nome, código, categoria, estoque, mínimo, preço, custo).

### Assistente IA (`assistente.dart`) — frame 6
- `Cabecalho('Assistente IA', 'Perguntas sobre a farmácia', descricao: 'Pergunte o que quiser - eu consulto seus dados!')`.
- Sem conversa: centralizado "Em que posso ajudar na farmácia?" (20 bold) + "Pergunte o que quiser - eu consulto seus dados!" (12 textoSuave).
- Campo de pergunta (raio 10, borda 1px, lupa à esquerda, hint "Pergunte sobre estoque, vendas, pedidos...",
  botão enviar à direita quando há texto) logo abaixo do título; na conversa ele fica fixo embaixo.
- Conversa: bolhas (usuário à direita em destaqueSuave; IA à esquerda em superficie com borda), indicador
  "pensando…" enquanto aguarda. Envia as **últimas 20** mensagens (`messages`), `escopo: 'todos'`.
  Respostas podem ter markdown simples (`**negrito**`, listas com `-`): renderizar negrito e manter quebras
  de linha (sem pacote de markdown). Botão "nova conversa" no cabeçalho (ícone `add_comment_outlined`).
- `CartaoComFaixa('Histórico', '<n> pergunta(s)')` no rodapé da tela (acima da nav): lista das perguntas
  anteriores (título vindo de `titulo` da resposta, ou a pergunta truncada) — tocar reabre a conversa.
  Vazio: "Suas perguntas aparecem aqui.". Histórico salvo em `shared_preferences` com chave
  `'aurafarma.ia.<userId>'` (JSON, máx. 30 conversas). Mostrar o cartão de histórico só quando não há
  conversa aberta (como no Figma); altura máx. ~180 com scroll.
- `GET /ia/config` no initState: se `enabled == false`, campo desabilitado + aviso "IA desativada no servidor."
- Erro 503/429 → mensagem do backend em bolha de erro.

### Contagem (`contagem.dart`) — frame 7 (mesma lógica do `Contagem.tsx` web)
- `Cabecalho('Contagem', 'Conferir estoque físico', descricao: 'Conferência periódica do estoque físico vs sistema.')`.
- Sem sessão: cartão (superficie, raio 12, borda 1px) "Iniciar nova contagem" (14 bold) + texto
  "Percorra a farmácia e registre o estoque físico de cada produto. Ao final, aplique os ajustes para
  alinhar o sistema com a realidade." + `BotaoLaranja('começar contagem', icone: format_list_bulleted)`.
  Abaixo `CartaoComFaixa('Contagens anteriores', '<n> realizada(s)')`: `Vazio(icone lista, 'Nenhuma contagem ainda')`
  ou lista (até 10): data/hora `formatarDataHora`, "<k> ajuste(s) aplicado(s)", `Selo('Diferença +x')`
  (tom sucesso se 0, destaque se >0, aviso se <0).
- Se `!populado`: `Vazio('Sem produtos para contar')`.
- Em sessão (estado local da tela: `Map<String, String> contados`): barra com busca, "<x> de <total> contados",
  botões "cancelar" (texto) e `BotaoLaranja('aplicar (<x>)')` (desabilitado se 0). Lista de produtos:
  nome + código | "sistema: n" | campo numérico 70px (só dígitos) | diferença (`Selo`: "igual" sucesso,
  +n destaque, -n aviso, "—" vazio). Aplicar → confirmação (AlertDialog) → `store.aplicarContagem` → SnackBar
  "Contagem aplicada · x ajuste(s) salvos" e sai da sessão. Busca usa `filtrarMedicamentos`.
- Atalho: ícone de câmera na barra da sessão abre o leitor (mesmo widget do scanner, em modal) e foca o produto lido.
  (Opcional — só se sobrar tempo; não é bloqueante.)

### Solicitados (`solicitados.dart`) — frame 8 (mesma lógica do `Solicitados.tsx` web)
- `Cabecalho('Solicitados', 'Pedidos de clientes', descricao: 'Pedidos de clientes que você ainda não tem em estoque.')`.
- Legenda "<n> produto(s) solicitado(s) por clientes" (12 textoSuave, padding 24).
- Cartão único (superficie, raio 12, borda 1px) com itens separados por divisória, ordenados por `pedidos` desc:
  nome (14) / nota (12 textoSuave, se houver) / "Último pedido em dd/mm/aaaa" (12 textoSuave) e à direita
  `Selo('<n> pedido(s)')` (destaque). Tocar no selo ou deslizar → ações.
- Ações por item: `+1` (somarSolicitacao), remover (Dismissible com fundo `perigo` + confirmação).
- FAB laranja (`Icons.add`) → bottom sheet "Registrar solicitação de cliente": "O que o cliente pediu?"
  (obrigatório, ex.: "Pomada para queimadura") e "Observação (opcional)" multiline → `registrarSolicitacao`.
- Vazio: `Vazio(bookmark, 'Nenhuma solicitação ainda')` + "Sempre que um cliente pedir algo que você não tem, registre aqui."
- `RefreshIndicator` → recarregar.

### Scanner (`scanner.dart`) — frame 9
- `Cabecalho('Scanner', 'Verificar código de barras', descricao: 'Escaneie o código do produto para acessar seu registro.')`.
- Legenda "Use a câmera do seu dispositivo" (12 textoSuave).
- Área da câmera: retângulo branco (superficie) raio 12, borda 1px, ~350×370, margem 31. Dentro:
  `MobileScanner` quando a câmera está ligada; desligada = vazio. Botão laranja 100×110 raio 24 com
  ícone de câmera branco 56, sobreposto à borda inferior da área (metade dentro/metade fora, como no Figma):
  liga/desliga a câmera.
- Ao ler (formatos EAN-13/EAN-8/UPC/Code128/QR): desliga a câmera, vibra (`HapticFeedback.mediumImpact`),
  mostra o resultado.
- Resultado: etiqueta laranja "Código de barras: <codigo>" (13 + código 11 bold branco) colada no topo de
  um cartão (superficie raio 10, borda 1px) com linha: nome + código | categoria | estoque (sucesso/perigo) |
  mín | preço. Se o código não estiver no estoque: "Produto não cadastrado no estoque" + botão
  "registrar como solicitado" → `registrarSolicitacao('Código <codigo>', 'Lido no scanner')`.
- Digitar manualmente: link "digitar código" abre dialog com campo numérico → mesma busca.
- Plataforma sem câmera (`!(Platform.isAndroid || Platform.isIOS)` ou `kIsWeb`): esconder `MobileScanner`,
  área mostra "Câmera indisponível neste dispositivo" e o botão laranja abre a digitação manual.
- Permissão negada / erro da câmera → `errorBuilder` com texto e o mesmo fallback manual.

## Verificação

- `flutter pub get` · `flutter analyze` (0 erros) · `flutter test`.
- `flutter build windows` e rodar contra o backend local (`npm --prefix backend run dev` no prototipo).
- Android: precisa do Android SDK (não instalado nesta máquina). Emulador usa `10.0.2.2`; celular físico
  usa o IP da máquina na rede: `flutter run --dart-define=API_BASE_URL=http://<ip>:4000/api`.

## Limitações conhecidas

- Login com Google não está no app (precisaria `google_sign_in` + client id Android).
- Dados escopados por **usuário** (igual ao web): funcionário precisa logar com a mesma conta do dono.
  Multi-usuário por farmácia (tenant) é o próximo passo do backend.
- Sem modo offline: sem internet as ações falham com "Sem conexão com o servidor.".
- Flutter web não é alvo: o navegador não deixa o app ler/mandar o cookie manualmente.

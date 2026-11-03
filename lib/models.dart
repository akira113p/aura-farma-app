// O QUE É ESTE ARQUIVO
// Classes de dados do app (Medicamentos, Usuario, Solicitacao, Contagem, Estado) e pequenas
// funções de busca e formatação. As classes sabem se criar a partir do JSON da API (`fromJson`).
// Quem usa: state/app_store.dart e quase todas as telas (main.dart reexporta este arquivo).
// Não depende do Flutter, por isso é fácil de testar. Veja GUIA_FLUTTER.md → JSON.

// Modelos do app e funções puras (sem dependência de Flutter, fáceis de testar).

// [ESCRITO À MÃO] classe original (nome, codigo, categorias, quantidade, preco) — movida de main.dart
// e estendida com id, minimo, custo, emBaixa, fromJson e copyWith
// Um produto do estoque (remédio). Classe só de dados, imutável: os campos são `final`
// (não mudam depois de criados); para "alterar" cria-se uma cópia (`copyWith`).
class Medicamentos {
  /// Identificador único dado pelo servidor.
  final String id;
  /// Nome do medicamento.
  final String nome;
  /// Código de barras / SKU, usado na busca e no scanner.
  final String codigo;
  /// Categoria do produto (ex.: analgésico).
  final String categorias;
  /// Quantidade em estoque.
  final int quantidade;
  /// Preço de venda.
  final double preco;
  /// Estoque mínimo: abaixo (ou igual) disso o produto está "em baixa".
  final int minimo;
  /// Quanto custou comprar o produto.
  final double custo;

  // Parâmetros nomeados: `required` = obrigatório; os com `= valor` são opcionais.
  Medicamentos({
    this.id = '',
    required this.nome,
    required this.codigo,
    required this.categorias,
    required this.quantidade,
    required this.preco,
    this.minimo = 0,
    this.custo = 0,
  });

  /// true quando o estoque está no mínimo ou abaixo. `get` = calculado ao ser lido, sem parênteses.
  bool get emBaixa => quantidade <= minimo;

  // Converte o JSON da API (Map) em Medicamentos. O servidor usa nomes em inglês
  // (name, sku, stock...). `'${j['id'] ?? ''}'` vira texto e usa '' se vier nulo;
  // `(... as num).toInt()` aceita número inteiro ou decimal e converte. Veja GUIA_FLUTTER.md → JSON.
  factory Medicamentos.fromJson(Map<String, dynamic> j) => Medicamentos(
        id: '${j['id'] ?? ''}',
        nome: '${j['name'] ?? ''}',
        codigo: '${j['sku'] ?? ''}',
        categorias: '${j['cat'] ?? ''}',
        quantidade: ((j['stock'] ?? 0) as num).toInt(),
        preco: ((j['price'] ?? 0) as num).toDouble(),
        minimo: ((j['min'] ?? 0) as num).toInt(),
        custo: ((j['cost'] ?? 0) as num).toDouble(),
      );

  /// Devolve uma cópia igual a este produto, trocando só a quantidade (se informada).
  /// `quantidade ?? this.quantidade` = usa a nova ou, se nula, a atual.
  Medicamentos copyWith({int? quantidade}) => Medicamentos(
        id: id,
        nome: nome,
        codigo: codigo,
        categorias: categorias,
        quantidade: quantidade ?? this.quantidade,
        preco: preco,
        minimo: minimo,
        custo: custo,
      );
}
// [FIM ESCRITO À MÃO]

/// Usuário logado. Dados vindos de `/auth/me` e `/auth/login`.
class Usuario {
  final String id;
  /// Nome de usuário (login).
  final String username;
  /// Nome da farmácia do usuário.
  final String pharmacyName;
  final String email;

  const Usuario({
    required this.id,
    required this.username,
    required this.pharmacyName,
    required this.email,
  });

  /// Converte o JSON do servidor em Usuario (campos ausentes viram texto vazio).
  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: '${j['id'] ?? ''}',
        username: '${j['username'] ?? ''}',
        pharmacyName: '${j['pharmacyName'] ?? ''}',
        email: '${j['email'] ?? ''}',
      );
}

/// Um medicamento que clientes pediram e a farmácia não tem (tela "solicitados").
class Solicitacao {
  final String id;
  final String nome;
  /// Observação livre.
  final String nota;
  /// Quantas vezes pediram esse item.
  final int pedidos;

  /// 'YYYY-MM-DD'
  final String data;

  const Solicitacao({
    required this.id,
    required this.nome,
    required this.nota,
    required this.pedidos,
    required this.data,
  });

  /// Converte o JSON do servidor em Solicitacao (`count` ausente conta como 1).
  factory Solicitacao.fromJson(Map<String, dynamic> j) => Solicitacao(
        id: '${j['id'] ?? ''}',
        nome: '${j['name'] ?? ''}',
        nota: '${j['note'] ?? ''}',
        pedidos: ((j['count'] ?? 1) as num).toInt(),
        data: '${j['date'] ?? ''}',
      );
}

/// Um item de uma contagem de estoque: qual produto, o novo valor e a diferença.
class AjusteContagem {
  /// Id do produto contado.
  final String pid;
  /// Quantidade encontrada na contagem.
  final int novoEstoque;
  /// Contado menos o que o sistema tinha (negativo = faltou).
  final int diferenca;

  const AjusteContagem({
    required this.pid,
    required this.novoEstoque,
    required this.diferenca,
  });

  /// Converte o JSON do servidor em AjusteContagem.
  factory AjusteContagem.fromJson(Map<String, dynamic> j) => AjusteContagem(
        pid: '${j['pid'] ?? ''}',
        novoEstoque: ((j['newStock'] ?? 0) as num).toInt(),
        diferenca: ((j['diff'] ?? 0) as num).toInt(),
      );
}

/// Uma contagem de estoque feita em certo momento, com a lista de ajustes.
class Contagem {
  final String id;
  /// Data e hora da contagem, no fuso do aparelho.
  final DateTime quando;
  /// Itens ajustados nessa contagem.
  final List<AjusteContagem> ajustes;

  const Contagem({
    required this.id,
    required this.quando,
    required this.ajustes,
  });

  /// Soma das diferenças de todos os itens. `fold` começa em 0 e acumula item a item.
  int get diferencaTotal => ajustes.fold(0, (s, a) => s + a.diferenca);

  /// Converte o JSON do servidor em Contagem. A data vem como texto ISO ('ts'); se for
  /// inválida usa 1970 (época 0) em vez de quebrar; `toLocal` ajusta para o fuso do aparelho.
  factory Contagem.fromJson(Map<String, dynamic> j) => Contagem(
        id: '${j['id'] ?? ''}',
        quando: (DateTime.tryParse('${j['ts'] ?? ''}') ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .toLocal(),
        ajustes: ((j['adjustments'] as List?) ?? const [])
            .map((a) =>
                AjusteContagem.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList(),
      );
}

/// Foto de todos os dados da farmácia carregados da API (`/estado`). Imutável.
class Estado {
  /// true se a conta já recebeu dados (exemplo ou reais).
  final bool populado;
  /// Produtos do estoque.
  final List<Medicamentos> produtos;
  /// Medicamentos solicitados por clientes.
  final List<Solicitacao> solicitacoes;
  /// Histórico de contagens.
  final List<Contagem> contagens;

  const Estado({
    required this.populado,
    required this.produtos,
    required this.solicitacoes,
    required this.contagens,
  });

  /// Estado inicial, sem nada (usado antes de carregar e ao deslogar).
  static const vazio = Estado(
    populado: false,
    produtos: [],
    solicitacoes: [],
    contagens: [],
  );

  /// Ignora `sales` e `activity`.
  factory Estado.fromJson(Map<String, dynamic> j) {
    // Função auxiliar local: pega a lista de JSON na chave [k] e converte cada item com [f].
    // `<T>` = serve para qualquer tipo de item. Chave ausente vira lista vazia (`?? const []`).
    List<T> lista<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? const [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    // O servidor usa nomes em inglês: products, requests, counts, populated.
    return Estado(
      populado: j['populated'] == true,
      produtos: lista('products', Medicamentos.fromJson),
      solicitacoes: lista('requests', Solicitacao.fromJson),
      contagens: lista('counts', Contagem.fromJson),
    );
  }

  /// Devolve uma cópia deste Estado trocando só o que for informado. É assim que o AppStore
  /// "atualiza" um dado imutável: cria um Estado novo.
  Estado copyWith({
    bool? populado,
    List<Medicamentos>? produtos,
    List<Solicitacao>? solicitacoes,
    List<Contagem>? contagens,
  }) =>
      Estado(
        populado: populado ?? this.populado,
        produtos: produtos ?? this.produtos,
        solicitacoes: solicitacoes ?? this.solicitacoes,
        contagens: contagens ?? this.contagens,
      );
}

// ---------------------------------------------------------------- funções puras

// Tabela usada para tirar acentos nas buscas, assim "analgésico" e "analgesico" casam.
const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Minúsculas e sem acento.
// Privada (`_`). Recebe um texto e devolve em minúsculas, sem acento e sem espaços nas pontas.
// `StringBuffer` monta o texto aos poucos, sem criar várias Strings intermediárias.
String _normalizar(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    // Troca a letra pela versão sem acento; se não estiver na tabela, mantém.
    b.write(_acentos[c] ?? c);
  }
  return b.toString().trim();
}

// [ESCRITO À MÃO] lógica do filtrarEstoque original (nome OU código, case-insensitive) — extraída
// para função pura; agora também ignora acento e filtra por categoria
// Filtra a lista de produtos por [texto] (nome ou código) e, opcionalmente, por [categoria].
// Devolve uma nova lista; a original não muda. Chamada pela tela de estoque a cada letra digitada.
List<Medicamentos> filtrarMedicamentos(List<Medicamentos> lista, String texto,
    {String? categoria}) {
  // Texto da busca já sem acento/maiúscula; os dados do produto passam pelo mesmo tratamento abaixo.
  final query = _normalizar(texto);
  return lista.where((med) {
    // Se há categoria escolhida e o produto não é dela, fora.
    if (categoria != null &&
        categoria.isNotEmpty &&
        med.categorias != categoria) {
      return false;
    }
    // Busca vazia: todos passam.
    if (query.isEmpty) return true;
    return _normalizar(med.nome).contains(query) ||
        _normalizar(med.codigo).contains(query);
  }).toList();
}
// [FIM ESCRITO À MÃO]

/// 'R$ 12,50'
// Troca o ponto decimal por vírgula (padrão brasileiro). `\$` escapa o cifrão.
String formatarPreco(double v) =>
    'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// Garante 2 dígitos: 5 vira '05'.
String _dois(int n) => n.toString().padLeft(2, '0');

/// 'dd/mm/aaaa'
// `${...}` insere o valor de uma expressão dentro do texto.
String formatarData(DateTime d) =>
    '${_dois(d.day)}/${_dois(d.month)}/${d.year}';

/// 'YYYY-MM-DD' -> 'dd/mm/aaaa' (devolve o texto original se não casar)
String formatarDataIso(String ymd) {
  // Remove a hora (tudo após o 'T') e separa ano, mês e dia.
  final p = ymd.split('T').first.split('-');
  // Formato inesperado: devolve o texto como veio.
  if (p.length != 3) return ymd;
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// 'dd/mm/aaaa hh:mm'
String formatarDataHora(DateTime d) =>
    '${formatarData(d)} ${_dois(d.hour)}:${_dois(d.minute)}';

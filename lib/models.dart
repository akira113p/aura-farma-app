// Modelos do app e funções puras (sem dependência de Flutter, fáceis de testar).

// [ESCRITO À MÃO] classe original (nome, codigo, categorias, quantidade, preco) — movida de main.dart
// e estendida com id, minimo, custo, emBaixa, fromJson e copyWith
class Medicamentos {
  final String id;
  final String nome;
  final String codigo;
  final String categorias;
  final int quantidade;
  final double preco;
  final int minimo;
  final double custo;

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

  bool get emBaixa => quantidade <= minimo;

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

class Usuario {
  final String id;
  final String username;
  final String pharmacyName;
  final String email;

  const Usuario({
    required this.id,
    required this.username,
    required this.pharmacyName,
    required this.email,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: '${j['id'] ?? ''}',
        username: '${j['username'] ?? ''}',
        pharmacyName: '${j['pharmacyName'] ?? ''}',
        email: '${j['email'] ?? ''}',
      );
}

class Solicitacao {
  final String id;
  final String nome;
  final String nota;
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

  factory Solicitacao.fromJson(Map<String, dynamic> j) => Solicitacao(
        id: '${j['id'] ?? ''}',
        nome: '${j['name'] ?? ''}',
        nota: '${j['note'] ?? ''}',
        pedidos: ((j['count'] ?? 1) as num).toInt(),
        data: '${j['date'] ?? ''}',
      );
}

class AjusteContagem {
  final String pid;
  final int novoEstoque;
  final int diferenca;

  const AjusteContagem({
    required this.pid,
    required this.novoEstoque,
    required this.diferenca,
  });

  factory AjusteContagem.fromJson(Map<String, dynamic> j) => AjusteContagem(
        pid: '${j['pid'] ?? ''}',
        novoEstoque: ((j['newStock'] ?? 0) as num).toInt(),
        diferenca: ((j['diff'] ?? 0) as num).toInt(),
      );
}

class Contagem {
  final String id;
  final DateTime quando;
  final List<AjusteContagem> ajustes;

  const Contagem({
    required this.id,
    required this.quando,
    required this.ajustes,
  });

  int get diferencaTotal => ajustes.fold(0, (s, a) => s + a.diferenca);

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

class Estado {
  final bool populado;
  final List<Medicamentos> produtos;
  final List<Solicitacao> solicitacoes;
  final List<Contagem> contagens;

  const Estado({
    required this.populado,
    required this.produtos,
    required this.solicitacoes,
    required this.contagens,
  });

  static const vazio = Estado(
    populado: false,
    produtos: [],
    solicitacoes: [],
    contagens: [],
  );

  /// Ignora `sales` e `activity`.
  factory Estado.fromJson(Map<String, dynamic> j) {
    List<T> lista<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? const [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    return Estado(
      populado: j['populated'] == true,
      produtos: lista('products', Medicamentos.fromJson),
      solicitacoes: lista('requests', Solicitacao.fromJson),
      contagens: lista('counts', Contagem.fromJson),
    );
  }

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

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Minúsculas e sem acento.
String _normalizar(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(_acentos[c] ?? c);
  }
  return b.toString().trim();
}

// [ESCRITO À MÃO] lógica do filtrarEstoque original (nome OU código, case-insensitive) — extraída
// para função pura; agora também ignora acento e filtra por categoria
List<Medicamentos> filtrarMedicamentos(List<Medicamentos> lista, String texto,
    {String? categoria}) {
  final query = _normalizar(texto);
  return lista.where((med) {
    if (categoria != null &&
        categoria.isNotEmpty &&
        med.categorias != categoria) {
      return false;
    }
    if (query.isEmpty) return true;
    return _normalizar(med.nome).contains(query) ||
        _normalizar(med.codigo).contains(query);
  }).toList();
}
// [FIM ESCRITO À MÃO]

/// 'R$ 12,50'
String formatarPreco(double v) =>
    'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

String _dois(int n) => n.toString().padLeft(2, '0');

/// 'dd/mm/aaaa'
String formatarData(DateTime d) =>
    '${_dois(d.day)}/${_dois(d.month)}/${d.year}';

/// 'YYYY-MM-DD' -> 'dd/mm/aaaa' (devolve o texto original se não casar)
String formatarDataIso(String ymd) {
  final p = ymd.split('T').first.split('-');
  if (p.length != 3) return ymd;
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// 'dd/mm/aaaa hh:mm'
String formatarDataHora(DateTime d) =>
    '${formatarData(d)} ${_dois(d.hour)}:${_dois(d.minute)}';

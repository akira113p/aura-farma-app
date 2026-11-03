import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Limites do contrato com o backend (`POST /api/ia/ask`).
const maxMensagensEnviadas = 20;
const maxCaracteres = 4000;
const maxConversas = 30;

class MensagemIA {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool erro;

  const MensagemIA(this.role, this.content, {this.erro = false});

  bool get doUsuario => role == 'user';

  Map<String, dynamic> toJson() =>
      {'role': role, 'content': content, if (erro) 'erro': true};

  factory MensagemIA.fromJson(Map<String, dynamic> j) => MensagemIA(
        j['role'] == 'assistant' ? 'assistant' : 'user',
        '${j['content'] ?? ''}',
        erro: j['erro'] == true,
      );
}

class ConversaIA {
  final String id;
  String titulo;
  final List<MensagemIA> mensagens;
  int atualizadoEm; // epoch ms

  ConversaIA({
    required this.id,
    required this.titulo,
    List<MensagemIA>? mensagens,
    int? atualizadoEm,
  })  : mensagens = mensagens ?? [],
        atualizadoEm = atualizadoEm ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'atualizadoEm': atualizadoEm,
        'mensagens': mensagens.map((m) => m.toJson()).toList(),
      };

  factory ConversaIA.fromJson(Map<String, dynamic> j) => ConversaIA(
        id: '${j['id']}',
        titulo: '${j['titulo'] ?? ''}',
        atualizadoEm: (j['atualizadoEm'] as num?)?.toInt(),
        mensagens: [
          for (final m in (j['mensagens'] as List? ?? const []))
            if (m is Map) MensagemIA.fromJson(Map<String, dynamic>.from(m)),
        ],
      );

  /// Corpo de `messages`: ignora bolhas de erro, pega as últimas 20 e corta cada
  /// content em 4000 caracteres.
  List<Map<String, String>> paraEnvio() {
    final ok = mensagens
        .where((m) => !m.erro && m.content.trim().isNotEmpty)
        .toList();
    final ultimas = ok.length > maxMensagensEnviadas
        ? ok.sublist(ok.length - maxMensagensEnviadas)
        : ok;
    return [
      for (final m in ultimas)
        {
          'role': m.role,
          'content': m.content.length > maxCaracteres
              ? m.content.substring(0, maxCaracteres)
              : m.content,
        },
    ];
  }
}

/// Título provisório: a pergunta truncada.
String tituloDaPergunta(String p) {
  final t = p.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.length > 60 ? '${t.substring(0, 57)}...' : t;
}

/// Histórico em shared_preferences, chave `aurafarma.ia.<userId>`.
class HistoricoIA {
  static String chave(String userId) => 'aurafarma.ia.$userId';

  static List<ConversaIA> decodificar(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final l = jsonDecode(raw);
      if (l is! List) return [];
      return [
        for (final c in l)
          if (c is Map) ConversaIA.fromJson(Map<String, dynamic>.from(c)),
      ];
    } catch (_) {
      return [];
    }
  }

  static String codificar(List<ConversaIA> conversas) =>
      jsonEncode(conversas.take(maxConversas).map((c) => c.toJson()).toList());

  static Future<List<ConversaIA>> carregar(String userId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return decodificar(p.getString(chave(userId)));
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvar(String userId, List<ConversaIA> conversas) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(chave(userId), codificar(conversas));
    } catch (_) {}
  }
}

// O QUE É ESTE ARQUIVO: modelos de dados da conversa com o Assistente de IA e o
// histórico guardado no próprio celular. NÃO tem telas (widgets), só dados e regras.
// Quem usa: `assistente.dart` (a tela do chat). Ele usa `shared_preferences`, um
// pequeno "caderninho" do celular que guarda textos simples mesmo depois de fechar o app.
// Os dados viram texto JSON (`toJson`) para salvar e voltam a objetos (`fromJson`).
// (veja GUIA_FLUTTER.md → Rede: HTTP, JSON, cookie)
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// maxMensagensEnviadas = quantas mensagens recentes mandamos à IA por pergunta;
/// maxCaracteres = tamanho máximo de cada mensagem; maxConversas = quantas
/// conversas guardamos no histórico. `const` global = valor fixo visível a todo o app.
/// Limites do contrato com o backend (`POST /api/ia/ask`).
const maxMensagensEnviadas = 20;
const maxCaracteres = 4000;
const maxConversas = 30;

/// Uma mensagem do chat (uma "bolha"): de quem é, o texto e se é uma mensagem de erro.
/// `const` no construtor permite criar mensagens imutáveis (que não mudam depois).
class MensagemIA {
  // role = quem falou: 'user' (o usuário) ou 'assistant' (a IA). Nomes em inglês
  // porque é o que o backend espera.
  final String role; // 'user' | 'assistant'
  // content = o texto da mensagem.
  final String content;
  // erro = true quando a "resposta" na verdade é um aviso de falha (aparece em vermelho
  // e NÃO é enviada de volta à IA nas próximas perguntas).
  final bool erro;

  // Construtor: role e content são posicionais (na ordem); `erro` é nomeado e opcional (padrão false).
  const MensagemIA(this.role, this.content, {this.erro = false});

  /// Atalho: true se a mensagem foi escrita pelo usuário (getter = "propriedade calculada").
  bool get doUsuario => role == 'user';

  /// Converte a mensagem para um Map (formato JSON) para salvar/enviar.
  /// O `if (erro) 'erro': true` dentro do Map só inclui a chave 'erro' quando for verdadeira.
  Map<String, dynamic> toJson() =>
      {'role': role, 'content': content, if (erro) 'erro': true};

  /// Faz o caminho inverso: recebe um Map lido do JSON e devolve uma MensagemIA.
  /// `factory` = construtor que pode decidir como criar o objeto. Aqui é defensivo:
  /// qualquer role desconhecida vira 'user' e `?? ''` troca um content nulo por texto vazio.
  factory MensagemIA.fromJson(Map<String, dynamic> j) => MensagemIA(
        j['role'] == 'assistant' ? 'assistant' : 'user',
        '${j['content'] ?? ''}',
        erro: j['erro'] == true,
      );
}

/// Uma conversa inteira: id, título, lista de mensagens e quando foi atualizada.
/// Cada item do histórico da tela do Assistente é uma ConversaIA.
class ConversaIA {
  // id = identificador único (gerado a partir da hora); é `final`, nunca muda.
  final String id;
  // titulo = nome mostrado no histórico (não é final: a IA pode sugerir um título melhor depois).
  String titulo;
  final List<MensagemIA> mensagens;
  // atualizadoEm = momento da última mudança, em milissegundos desde 1970 ("epoch ms").
  int atualizadoEm; // epoch ms

  // Construtor com lista de inicializadores (depois dos `:`): se `mensagens` vier nulo
  // usa uma lista vazia (`??`); se `atualizadoEm` vier nulo usa a hora de agora.
  ConversaIA({
    required this.id,
    required this.titulo,
    List<MensagemIA>? mensagens,
    int? atualizadoEm,
  })  : mensagens = mensagens ?? [],
        atualizadoEm = atualizadoEm ?? DateTime.now().millisecondsSinceEpoch;

  /// Transforma a conversa em Map/JSON para gravar no celular (mensagens viram uma lista de Maps).
  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'atualizadoEm': atualizadoEm,
        'mensagens': mensagens.map((m) => m.toJson()).toList(),
      };

  /// Reconstrói uma conversa a partir do JSON salvo.
  /// `as num?` aceita número inteiro ou decimal (ou nulo) e `.toInt()` converte.
  /// O `for ... if (m is Map)` dentro da lista ignora itens que não sejam Map (dados estragados).
  factory ConversaIA.fromJson(Map<String, dynamic> j) => ConversaIA(
        id: '${j['id']}',
        titulo: '${j['titulo'] ?? ''}',
        atualizadoEm: (j['atualizadoEm'] as num?)?.toInt(),
        mensagens: [
          for (final m in (j['mensagens'] as List? ?? const []))
            if (m is Map) MensagemIA.fromJson(Map<String, dynamic>.from(m)),
        ],
      );

  /// Prepara a lista de mensagens que será enviada à IA na pergunta.
  /// Devolve uma lista de Maps {'role','content'}. Chamada pela tela do Assistente a cada envio.
  /// Por que filtra/corta: o servidor aceita no máximo 20 mensagens de 4000 caracteres.
  /// Corpo de `messages`: ignora bolhas de erro, pega as últimas 20 e corta cada
  /// content em 4000 caracteres.
  List<Map<String, String>> paraEnvio() {
    // (1) Fica só com mensagens que não são erro e não estão vazias.
    final ok = mensagens
        .where((m) => !m.erro && m.content.trim().isNotEmpty)
        .toList();
    // (2) Se passar do limite, fica com as ÚLTIMAS (sublist pega do índice dado até o fim).
    final ultimas = ok.length > maxMensagensEnviadas
        ? ok.sublist(ok.length - maxMensagensEnviadas)
        : ok;
    // (3) Monta a lista final, cortando cada texto no tamanho máximo.
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

/// Gera um título provisório para a conversa a partir da primeira pergunta:
/// tira espaços das pontas, junta espaços/quebras repetidos em um só e, se passar
/// de 60 caracteres, corta em 57 e põe "..." no fim.
/// Título provisório: a pergunta truncada.
String tituloDaPergunta(String p) {
  final t = p.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.length > 60 ? '${t.substring(0, 57)}...' : t;
}

/// Só métodos `static` (não precisa criar objeto): `HistoricoIA.carregar(...)`.
/// Cada usuário tem a sua chave, assim contas diferentes no mesmo celular não misturam histórico.
/// Histórico em shared_preferences, chave `aurafarma.ia.<userId>`.
class HistoricoIA {
  /// Monta o nome da chave onde o histórico daquele usuário é guardado.
  static String chave(String userId) => 'aurafarma.ia.$userId';

  /// Converte o texto salvo (JSON) em lista de conversas. Se o texto for nulo, vazio,
  /// não for uma lista ou estiver corrompido, devolve lista vazia em vez de travar o app.
  static List<ConversaIA> decodificar(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final l = jsonDecode(raw);
      if (l is! List) return [];
      return [
        for (final c in l)
          if (c is Map) ConversaIA.fromJson(Map<String, dynamic>.from(c)),
      ];
    // Qualquer erro ao ler o JSON (ex.: texto quebrado) cai aqui e vira "sem histórico".
    } catch (_) {
      return [];
    }
  }

  /// Converte as conversas em texto JSON; `take(maxConversas)` guarda só as 30 primeiras (mais recentes).
  static String codificar(List<ConversaIA> conversas) =>
      jsonEncode(conversas.take(maxConversas).map((c) => c.toJson()).toList());

  /// Lê o histórico do usuário no celular. É `Future` (resultado vem depois) porque
  /// acessar o armazenamento é assíncrono; o `await` espera sem travar a tela.
  /// Em caso de erro devolve lista vazia.
  static Future<List<ConversaIA>> carregar(String userId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return decodificar(p.getString(chave(userId)));
    } catch (_) {
      return [];
    }
  }

  /// Grava o histórico do usuário no celular. O `catch (_) {}` vazio é proposital:
  /// se não conseguir salvar, o app segue funcionando (o histórico é só uma comodidade).
  static Future<void> salvar(String userId, List<ConversaIA> conversas) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(chave(userId), codificar(conversas));
    } catch (_) {}
  }
}

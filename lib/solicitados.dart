import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'models.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cabecalho.dart';
import 'widgets/cartao.dart';
import 'widgets/icones.dart';

// [ESCRITO À MÃO] esqueleto original: TelaSolicitados (StatefulWidget) + _TelaSolicitados com Scaffold.
// Mantidos os nomes das classes; o AppBar(title: "Solicitados") foi trocado pelo Cabecalho do Figma,
// o Column vazio do body virou o conteúdo da tela e foi adicionado o FAB de registro.
class TelaSolicitados extends StatefulWidget {
  const TelaSolicitados({super.key});

  @override
  State<TelaSolicitados> createState() => _TelaSolicitados();
}

class _TelaSolicitados extends State<TelaSolicitados> {
  // [FIM ESCRITO À MÃO]

  /// ids com requisição em andamento (evita duplo envio).
  final Set<String> _ocupados = {};

  void _erro(ApiException e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }

  Future<void> _somar(Solicitacao s) async {
    if (_ocupados.contains(s.id)) return;
    final store = AppScope.read(context);
    setState(() => _ocupados.add(s.id));
    try {
      await store.somarSolicitacao(s);
    } on ApiException catch (e) {
      if (mounted) _erro(e);
    } finally {
      if (mounted) setState(() => _ocupados.remove(s.id));
    }
  }

  Future<bool> _confirmarRemocao(Solicitacao s) async {
    final store = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover solicitação?'),
        content: Text('"${s.nome}" será removido da lista.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('remover')),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      // Remove no servidor; o store tira o item da lista, então o Dismissible
      // não precisa (nem deve) sair sozinho — devolvemos false.
      await store.removerSolicitacao(s.id);
    } on ApiException catch (e) {
      if (mounted) _erro(e);
    }
    return false;
  }

  void _abrirRegistro() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCores.of(context).superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _FormularioSolicitacao(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    final store = AppScope.of(context);
    final lista = [...store.estado.solicitacoes]
      ..sort((a, b) => b.pedidos.compareTo(a.pedidos));

    // [ESCRITO À MÃO] Scaffold + body Column do esqueleto — AppBar substituído pelo Cabecalho (Figma)
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: c.destaque,
        foregroundColor: Colors.white,
        tooltip: 'Registrar solicitação',
        onPressed: _abrirRegistro,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Cabecalho(
              titulo: 'Solicitados',
              subtitulo: 'Pedidos de clientes',
              descricao: 'Pedidos de clientes que você ainda não tem em estoque.',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => AppScope.read(context).recarregar(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 88),
                  children: [
                    if (lista.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 8),
                        child: Text(
                            '${lista.length} produto(s) solicitado(s) por clientes',
                            style:
                                TextStyle(fontSize: 12, color: c.textoSuave)),
                      ),
                    if (lista.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: c.superficie,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.borda),
                        ),
                        child: Column(
                          children: [
                            const Vazio(
                                icone: Ico.solicitados,
                                texto: 'Nenhuma solicitação ainda'),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                  'Sempre que um cliente pedir algo que você não tem, registre aqui.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: c.textoSuave)),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: c.superficie,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.borda),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < lista.length; i++)
                              _item(lista[i], primeiro: i == 0),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // [FIM ESCRITO À MÃO]
  }

  Widget _item(Solicitacao s, {required bool primeiro}) {
    final c = AppCores.of(context);
    final ocupado = _ocupados.contains(s.id);
    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmarRemocao(s),
      background: Container(
        color: c.perigo,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.superficie,
          border: primeiro ? null : Border(top: BorderSide(color: c.borda)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nome,
                      style: TextStyle(fontSize: 14, color: c.texto)),
                  if (s.nota.isNotEmpty)
                    Text(s.nota,
                        style: TextStyle(fontSize: 12, color: c.textoSuave)),
                  Text('Último pedido em ${formatarDataIso(s.data)}',
                      style: TextStyle(fontSize: 12, color: c.textoSuave)),
                ],
              ),
            ),
            Selo('${s.pedidos} pedido(s)'),
            IconButton(
              tooltip: '+1 pedido',
              visualDensity: VisualDensity.compact,
              onPressed: ocupado ? null : () => _somar(s),
              icon: ocupado
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('+1',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: c.destaque)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet "Registrar solicitação de cliente".
class _FormularioSolicitacao extends StatefulWidget {
  const _FormularioSolicitacao();

  @override
  State<_FormularioSolicitacao> createState() => _FormularioSolicitacaoState();
}

class _FormularioSolicitacaoState extends State<_FormularioSolicitacao> {
  final _nome = TextEditingController();
  final _nota = TextEditingController();
  bool _enviando = false;
  String? _erroNome;

  @override
  void dispose() {
    _nome.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erroNome = 'Informe o que o cliente pediu.');
      return;
    }
    final store = AppScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _enviando = true;
      _erroNome = null;
    });
    try {
      await store.registrarSolicitacao(nome, _nota.text.trim());
      navigator.pop();
    } on ApiException catch (e) {
      // Erro dentro do próprio sheet: um SnackBar ficaria escondido atrás dele.
      if (mounted) {
        setState(() {
          _enviando = false;
          _erroNome = e.message;
        });
      }
    }
  }

  InputDecoration _deco(AppCores c, String rotulo, {String? hint, String? erro}) =>
      InputDecoration(
        labelText: rotulo,
        hintText: hint,
        errorText: erro,
        labelStyle: TextStyle(color: c.textoSuave),
        hintStyle: TextStyle(color: c.textoFraco),
        filled: true,
        fillColor: c.fundo,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.borda)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.destaque)),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Padding(
      // Sobe junto com o teclado.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registrar solicitação de cliente',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.texto)),
            const SizedBox(height: 16),
            TextField(
              controller: _nome,
              enabled: !_enviando,
              autofocus: true,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: c.texto),
              decoration: _deco(c, 'O que o cliente pediu?',
                  hint: 'Pomada para queimadura', erro: _erroNome),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nota,
              enabled: !_enviando,
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              style: TextStyle(color: c.texto),
              decoration: _deco(c, 'Observação (opcional)'),
            ),
            const SizedBox(height: 16),
            BotaoLaranja(
              texto: 'registrar',
              carregando: _enviando,
              onPressed: _enviar,
            ),
          ],
        ),
      ),
    );
  }
}

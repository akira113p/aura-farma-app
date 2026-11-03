import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/api_client.dart';
import 'models.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cabecalho.dart';
import 'widgets/cartao.dart';
import 'widgets/icones.dart';

// [ESCRITO À MÃO] esqueleto original: TelaContagem (StatefulWidget) + _TelaContagem com Scaffold.
// Mantidos os nomes das classes; o AppBar(title: "Contagem") foi trocado pelo Cabecalho do Figma
// e o Column vazio do body agora recebe o conteúdo da tela.
class TelaContagem extends StatefulWidget {
  const TelaContagem({super.key});

  @override
  State<TelaContagem> createState() => _TelaContagem();
}

class _TelaContagem extends State<TelaContagem> {
  // [FIM ESCRITO À MÃO]

  /// Sessão de contagem aberta?
  bool _emSessao = false;

  /// id do produto -> texto digitado (só dígitos).
  final Map<String, String> _contados = {};

  /// Um controller por produto (criado sob demanda; descartado ao sair da sessão).
  final Map<String, TextEditingController> _controllers = {};

  final TextEditingController _busca = TextEditingController();
  bool _aplicando = false;

  @override
  void dispose() {
    _busca.dispose();
    _descartarControllers();
    super.dispose();
  }

  void _descartarControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  TextEditingController _controllerDe(String id) =>
      _controllers.putIfAbsent(id, () => TextEditingController(text: _contados[id] ?? ''));

  void _iniciar() {
    setState(() {
      _emSessao = true;
      _contados.clear();
      _busca.clear();
    });
  }

  void _encerrarSessao() {
    // Os TextFields da sessão ainda estão montados neste frame: só descarta os
    // controllers depois que a árvore for reconstruída sem eles.
    final antigos = _controllers.values.toList();
    _controllers.clear();
    setState(() {
      _emSessao = false;
      _contados.clear();
      _busca.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in antigos) {
        c.dispose();
      }
    });
  }

  void _alterou(String id, String valor) {
    setState(() {
      if (valor.isEmpty) {
        _contados.remove(id);
      } else {
        _contados[id] = valor;
      }
    });
  }

  Future<void> _aplicar() async {
    final store = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ajustes = <String, int>{};
    _contados.forEach((id, v) {
      final n = int.tryParse(v);
      if (n != null) ajustes[id] = n;
    });
    if (ajustes.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar contagem?'),
        content: Text(
            '${ajustes.length} produto(s) terão o estoque do sistema ajustado para o valor contado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('aplicar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _aplicando = true);
    try {
      await store.aplicarContagem(ajustes);
      messenger.showSnackBar(SnackBar(
          content: Text('Contagem aplicada · ${ajustes.length} ajuste(s) salvos')));
      if (mounted) _encerrarSessao();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final estado = store.estado;

    // [ESCRITO À MÃO] Scaffold + body Column do esqueleto — AppBar substituído pelo Cabecalho (Figma)
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Cabecalho(
              titulo: 'Contagem',
              subtitulo: 'Conferir estoque físico',
              descricao: 'Conferência periódica do estoque físico vs sistema.',
            ),
            Expanded(
              child: store.carregandoEstado && !estado.populado
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppCores.of(context).destaque))
                  : !estado.populado
                  ? const Center(
                      child: Vazio(
                          icone: Ico.contagem,
                          texto: 'Sem produtos para contar'))
                  : (_emSessao
                      ? _sessao(estado.produtos)
                      : _inicio(estado.contagens)),
            ),
          ],
        ),
      ),
    );
    // [FIM ESCRITO À MÃO]
  }

  // ------------------------------------------------------------ sem sessão

  Widget _inicio(List<Contagem> contagens) {
    final c = AppCores.of(context);
    final recentes = contagens.take(10).toList();
    return RefreshIndicator(
      onRefresh: () => AppScope.read(context).recarregar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            // Figma: o cartão "Iniciar nova contagem" é transparente (cinza do fundo) com borda
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borda),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Iniciar nova contagem',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: c.texto)),
                const SizedBox(height: 6),
                Text(
                    'Percorra a farmácia e registre o estoque físico de cada produto. Ao final, aplique os ajustes para alinhar o sistema com a realidade.',
                    style: TextStyle(fontSize: 13, color: c.textoSuave)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BotaoLaranja(
                    texto: 'começar contagem',
                    icone: Ico.contagem,
                    onPressed: _iniciar,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CartaoComFaixa(
            titulo: 'Contagens anteriores',
            contador: '${contagens.length} realizada(s)',
            child: recentes.isEmpty
                ? const Vazio(
                    icone: Ico.contagem, texto: 'Nenhuma contagem ainda')
                : Column(
                    children: [
                      for (var i = 0; i < recentes.length; i++)
                        _linhaContagem(recentes[i], primeira: i == 0),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _linhaContagem(Contagem ct, {required bool primeira}) {
    final c = AppCores.of(context);
    final dif = ct.diferencaTotal;
    final tom = dif == 0
        ? TomSelo.sucesso
        : (dif > 0 ? TomSelo.destaque : TomSelo.aviso);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: primeira ? null : Border(top: BorderSide(color: c.borda)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatarDataHora(ct.quando),
                    style: TextStyle(fontSize: 14, color: c.texto)),
                Text('${ct.ajustes.length} ajuste(s) aplicado(s)',
                    style: TextStyle(fontSize: 12, color: c.textoSuave)),
              ],
            ),
          ),
          Selo('Diferença ${dif > 0 ? '+' : ''}$dif', tom: tom),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- sessão

  Widget _sessao(List<Medicamentos> produtos) {
    final c = AppCores.of(context);
    final lista = filtrarMedicamentos(produtos, _busca.text);
    final contados = _contados.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _busca,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: c.texto),
                  decoration: InputDecoration(
                    hintText: 'buscar por nome, código',
                    hintStyle: TextStyle(fontSize: 13, color: c.textoFraco),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ico(Ico.busca, size: 20, color: c.textoSuave),
                    ),
                    filled: true,
                    fillColor: c.superficie,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.borda)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.destaque)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('$contados de ${produtos.length} contados',
                        style: TextStyle(fontSize: 12, color: c.textoSuave)),
                  ),
                  TextButton(
                    onPressed: _aplicando ? null : _encerrarSessao,
                    child: Text('cancelar',
                        style: TextStyle(color: c.textoSuave)),
                  ),
                  const SizedBox(width: 6),
                  BotaoLaranja(
                    texto: 'aplicar ($contados)',
                    carregando: _aplicando,
                    onPressed: contados == 0 ? null : _aplicar,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Text('Nenhum produto encontrado',
                      style: TextStyle(fontSize: 13, color: c.textoSuave)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  itemCount: lista.length,
                  itemBuilder: (_, i) => _linhaProduto(lista[i], i == 0),
                ),
        ),
      ],
    );
  }

  Widget _linhaProduto(Medicamentos p, bool primeira) {
    final c = AppCores.of(context);
    final n = int.tryParse(_contados[p.id] ?? '');
    final Widget selo;
    if (n == null) {
      selo = Text('—', style: TextStyle(fontSize: 12, color: c.textoFraco));
    } else {
      final d = n - p.quantidade;
      selo = d == 0
          ? const Selo('igual', tom: TomSelo.sucesso)
          : Selo(d > 0 ? '+$d' : '$d',
              tom: d > 0 ? TomSelo.destaque : TomSelo.aviso);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: c.superficie,
        border: Border(
          left: BorderSide(color: c.borda),
          right: BorderSide(color: c.borda),
          bottom: BorderSide(color: c.borda),
          top: primeira ? BorderSide(color: c.borda) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: c.texto)),
                Text(p.codigo,
                    style: TextStyle(fontSize: 10, color: c.textoSuave)),
                Text('sistema: ${p.quantidade}',
                    style: TextStyle(fontSize: 11, color: c.textoSuave)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            height: 38,
            child: TextField(
              controller: _controllerDe(p.id),
              enabled: !_aplicando,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.texto),
              onChanged: (v) => _alterou(p.id, v),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: c.textoFraco),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: c.fundo,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.borda)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.destaque)),
              ),
            ),
          ),
          SizedBox(width: 62, child: Center(child: selo)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'config.dart';
import 'core/api_client.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cartao.dart';

/// Tela de login (mesma conta do auraFarma web).
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _id = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultar = true;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _id.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_carregando) return;
    final id = _id.text.trim();
    if (id.isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Informe e-mail/usuário e senha.');
      return;
    }
    final store = AppScope.read(context);
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await store.entrar(id, _senha.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _trocarServidor() async {
    final api = AppScope.read(context).api;
    final ctrl = TextEditingController(text: AppConfig.baseUrl);
    final acao = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Endereço do backend. Ex.: meu-tunel.trycloudflare.com ou 192.168.0.10:4000'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://...'),
              onSubmitted: (_) => Navigator.pop(ctx, 'salvar'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'padrao'),
              child: const Text('padrão')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'salvar'),
              child: const Text('salvar')),
        ],
      ),
    );
    final texto = ctrl.text;
    ctrl.dispose();
    if (acao == null) return;
    await AppConfig.definirServidor(acao == 'padrao' ? null : texto);
    await api.limparSessao(); // o cookie era de outro servidor
    if (mounted) setState(() => _erro = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Scaffold(
      backgroundColor: c.fundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.destaque,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('f',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('auraFarma',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: c.texto)),
                  const SizedBox(height: 4),
                  Text('Entre na sua conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textoSuave)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _id,
                    enabled: !_carregando,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration:
                        const InputDecoration(hintText: 'E-mail ou usuário'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _senha,
                    enabled: !_carregando,
                    obscureText: _ocultar,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _entrar(),
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultar
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: c.textoSuave,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(_erro!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.perigo, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  BotaoLaranja(
                    texto: 'Entrar',
                    carregando: _carregando,
                    onPressed: _entrar,
                  ),
                  const SizedBox(height: 24),
                  Text('Use a mesma conta do auraFarma web.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.textoSuave)),
                  const SizedBox(height: 4),
                  // Toque para trocar o servidor (ex.: URL do túnel quando você está no 4G)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _carregando ? null : _trocarServidor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text('Servidor: ${AppConfig.baseUrl}',
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: c.textoFraco)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined,
                              size: 13, color: c.textoFraco),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

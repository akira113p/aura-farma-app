// O QUE É ESTE ARQUIVO
// Testa o AppConfig (config.dart): a classe que guarda o endereço do servidor (backend) que o app usa.
// Como rodar:  flutter test test/config_test.dart   (ou só 'flutter test' para rodar todos).
// Precisa de: nada. Não usa internet nem backend; tudo roda na memória.
// Passou = o app sabe ajeitar endereços digitados e lembrar o servidor escolhido. Falhou = alguém quebrou essa regra.
// Dica: veja a seção 'Testes' do GUIA_FLUTTER.md para entender 'test' e 'expect'.
//
import 'package:aurafarma_app/config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // CENÁRIO: vários endereços digitados do jeito que uma pessoa digitaria (com ou sem https, com barra no fim, com espaços).
  // AÇÃO: chama AppConfig.normalizarUrl em cada um.
  // CONFERIDO: o resultado sempre tem esquema (https/http) e termina em /api. Isso importa porque o usuário cola o link do túnel
  // na tela de login e o app precisa montar a URL certa sem ele se preocupar com detalhes.
  // 'test(nome, função)' é um teste de uma função comum; 'expect(valor, esperado)' confere se o valor é igual ao esperado
  // (se não for, o teste falha e mostra a diferença).
  test('normalizarUrl: esquema e /api', () {
    expect(AppConfig.normalizarUrl('meu-tunel.trycloudflare.com'),
        'https://meu-tunel.trycloudflare.com/api');
    expect(AppConfig.normalizarUrl('https://x.trycloudflare.com/'),
        'https://x.trycloudflare.com/api');
    expect(AppConfig.normalizarUrl('192.168.0.10:4000'),
        'http://192.168.0.10:4000/api');
    expect(AppConfig.normalizarUrl('localhost:4000/api'),
        'http://localhost:4000/api');
    expect(AppConfig.normalizarUrl('  http://10.0.2.2:4000/api  '),
        'http://10.0.2.2:4000/api');
  });

  // CENÁRIO: o app 'sem nada salvo' (preferências vazias) e depois salvando um servidor novo.
  // AÇÃO: define o servidor, confere que vale na hora, 'reabre' o app (carregar) e depois volta ao padrão.
  // CONFERIDO: a escolha do usuário é guardada no aparelho e a opção de voltar ao padrão (passando null) funciona.
  // 'async/await' aparece porque salvar no aparelho demora um instante; 'await' espera terminar.
  test('definirServidor salva, vale na hora e volta ao padrão', () async {
    // SharedPreferences é o 'bloco de notas' do Android/iOS onde o app guarda configurações pequenas.
    // No teste não existe aparelho, então setMockInitialValues cria um bloco de notas falso e vazio na memória.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    // Guarda o endereço padrão atual, para comparar no final se voltou ao normal.
    final padrao = AppConfig.baseUrl;
    // Salva um servidor novo (sem https; a função deve completar sozinha).
    await AppConfig.definirServidor('abc.trycloudflare.com');
    expect(AppConfig.baseUrl, 'https://abc.trycloudflare.com/api');
    // Simula fechar e abrir o app: recarrega do 'bloco de notas' e o endereço salvo tem que continuar lá.
    // sobrevive a "reabrir o app"
    await AppConfig.carregar();
    expect(AppConfig.baseUrl, 'https://abc.trycloudflare.com/api');
    // Passar null apaga o servidor salvo; o app deve voltar ao endereço padrão.
    await AppConfig.definirServidor(null);
    expect(AppConfig.baseUrl, padrao);
  });
}

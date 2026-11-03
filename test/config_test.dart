import 'package:aurafarma_app/config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  test('definirServidor salva, vale na hora e volta ao padrão', () async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final padrao = AppConfig.baseUrl;
    await AppConfig.definirServidor('abc.trycloudflare.com');
    expect(AppConfig.baseUrl, 'https://abc.trycloudflare.com/api');
    // sobrevive a "reabrir o app"
    await AppConfig.carregar();
    expect(AppConfig.baseUrl, 'https://abc.trycloudflare.com/api');
    await AppConfig.definirServidor(null);
    expect(AppConfig.baseUrl, padrao);
  });
}

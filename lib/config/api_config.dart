class ApiConfig {
  ApiConfig._();

  static const String authBaseUrl = String.fromEnvironment(
    'ECORUTA_AUTH_URL',
    defaultValue: 'https://ecoruta05-production.up.railway.app',
  );

  static const String iaBaseUrl = String.fromEnvironment(
    'ECORUTA_IA_URL',
    defaultValue:
        'https://captivating-perfection-production-3c07.up.railway.app',
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/constants.dart';

void main() {
  test('API base URL strips duplicated /api/v1 suffix', () {
    expect(
      normalizeApiBaseUrl('https://api.inpr1me.ru/api/v1/'),
      'https://api.inpr1me.ru',
    );
    expect(
      '${normalizeApiBaseUrl('https://api.inpr1me.ru/api/v1/')}$kApiPrefix/skills',
      'https://api.inpr1me.ru/api/v1/skills',
    );
  });
}

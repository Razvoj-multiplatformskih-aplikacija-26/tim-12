// ApiError: `{code, data}` oblik i nepoznat-kôd fallback.
//
// Stara verzija aplikacije ne sme da padne kad server posalje kôd koji
// ne poznaje (npr. novo pravilo dodato na serveru): nepoznat kôd prolazi
// kao obican string, a tipizovani prevod tada vrati `null`.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:test/test.dart';

void main() {
  test('cita code i data iz odgovora servera', () {
    final error = ApiError.fromJson({
      'code': 'invalid_credentials',
      'data': {'attemptsLeft': 2},
    });

    expect(error.code, 'invalid_credentials');
    expect(error.data, {'attemptsLeft': 2});
    expect(error.isKnown, isTrue);
  });

  test('nepoznat kôd ne rusi parsiranje (fallback)', () {
    final error = ApiError.fromJson({
      'code': 'novo_pravilo_sa_servera',
      'data': {'foo': 'bar'},
    });

    expect(error.code, 'novo_pravilo_sa_servera');
    expect(error.isKnown, isFalse);
    expect(error.toJson()['code'], 'novo_pravilo_sa_servera');
  });

  test('odgovor bez koda postaje unknown_error', () {
    expect(ApiError.fromJson({}).code, ErrorCodes.unknown);
    expect(ApiError.fromJson({'code': ''}).code, ErrorCodes.unknown);
    expect(ApiError.fromJson({'code': 42}).code, ErrorCodes.unknown);
  });

  test('neispravno data postaje prazna mapa, ne pad', () {
    expect(ApiError.fromJson({'code': 'x', 'data': 'tekst'}).data, isEmpty);
    expect(ApiError.fromJson({'code': 'x', 'data': null}).data, isEmpty);
    expect(ApiError.fromJson({'code': 'x'}).data, isEmpty);
  });

  test('toJson/fromJson krug za poznat kôd', () {
    const error = ApiError(
      code: ErrorCodes.backofficeNotAllowed,
      data: {'role': 'listener'},
    );

    expect(ApiError.fromJson(error.toJson()), error);
  });
}

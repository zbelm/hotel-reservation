import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_reservation/format.dart';

void main() {
  test('counts nights between two dates', () {
    expect(nightsBetween('2026-10-08', '2026-10-11'), 3);
  });

  test('labels guests', () {
    expect(guests(2, 0), '2 adults');
    expect(guests(1, 1), '1 adult, 1 child');
    expect(guests(2, 2), '2 adults, 2 children');
  });

  test('formats pesos without decimals', () {
    expect(money(11400), '₱11,400');
    expect(money('2500.00'), '₱2,500');
  });
}

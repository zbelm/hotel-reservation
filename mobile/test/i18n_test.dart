import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_reservation/format.dart';
import 'package:hotel_reservation/hotel.dart';
import 'package:hotel_reservation/i18n.dart';

void main() {
  tearDown(() => appLang.value = 'en');

  test('switches text between English and Filipino', () {
    expect(tr('Book', 'Mag-book'), 'Book');
    appLang.value = 'fil';
    expect(tr('Book', 'Mag-book'), 'Mag-book');
    expect(guests(2, 1), '2 matanda, 1 bata');
    expect(nights(3), '3 gabi');
    expect(statusLabel('confirmed'), 'Kumpirmado');
  });

  test('hotel content says the same thing in both languages', () {
    final en = hotel;
    appLang.value = 'fil';
    final fil = hotel;
    expect(fil.policies.length, en.policies.length);
    expect(fil.faqs.length, en.faqs.length);
    expect(fil.facilities.length, en.facilities.length);
    expect(fil.arrivalTimes.keys, en.arrivalTimes.keys);
    expect(arrivalLabel('6pm_8pm'), '6 PM hanggang 8 PM');
  });

  test('labels nights in English', () {
    expect(nights(1), '1 night');
    expect(statusLabel('checked_out'), 'Completed');
  });
}

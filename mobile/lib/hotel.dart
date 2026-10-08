// Everything guests read about the hotel, in English and Filipino. Same sample content as the
// website (web/src/lib/hotel.ts): replace it with the hotel's real details before taking real
// bookings, and keep the two languages saying the same thing.
import 'package:flutter/material.dart';

import 'config.dart';
import 'i18n.dart';

const hotelAddress = '123 Seaside Avenue, Pasay City, Metro Manila';
const hotelPhone = '+63 2 8123 4567';
const hotelEmail = 'stay@samplebayhotel.ph';
const _lat = 14.5352, _lng = 120.9822;
final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_lat,$_lng');
final phoneUrl = Uri.parse('tel:${hotelPhone.replaceAll(' ', '')}');

class Facility {
  const Facility(this.icon, this.name, this.detail);
  final IconData icon;
  final String name, detail;
}

class TextPair {
  const TextPair(this.title, this.body);
  final String title, body;
}

class HotelContent {
  const HotelContent({
    required this.aboutHeading,
    required this.about,
    required this.facts,
    required this.facilities,
    required this.gettingHere,
    required this.policies,
    required this.faqs,
    required this.arrivalTimes,
    required this.requestIdeas,
  });
  final String aboutHeading;
  final List<String> about;
  final List<TextPair> facts, policies, faqs;
  final List<Facility> facilities;
  final List<String> gettingHere, requestIdeas;
  final Map<String, String> arrivalTimes; // value -> label, in display order
}

HotelContent get hotel => isFil ? _fil : _en;

String? arrivalLabel(String? value) => value == null ? null : hotel.arrivalTimes[value];

const _en = HotelContent(
  aboutHeading: 'A small hotel on the bay, twelve rooms and a long view west',
  about: [
    'We built $hotelName for people who want the city close but not loud. Every room faces the water, and the capiz shell windows in the lobby are the same ones that hung here when the house was first built.',
    'Mornings start with coffee and pandesal in the café. Evenings are for the rooftop, where the sun drops behind the bay a little after six.',
  ],
  facts: [
    TextPair('Check-in', 'From $checkInTime'),
    TextPair('Check-out', 'By $checkOutTime'),
    TextPair('Front desk', 'Open 24 hours'),
    TextPair('Rooms', '12 rooms on 3 floors, all non-smoking'),
  ],
  facilities: [
    Facility(Icons.pool, 'Rooftop pool', 'Open 7 AM to 9 PM. Towels at the pool desk.'),
    Facility(Icons.restaurant, 'Café and restaurant',
        "Breakfast 6:30 to 10:30 AM, dinner until 10 PM. Breakfast is ₱450 if your rate doesn't include it."),
    Facility(Icons.wifi, 'Free Wi-Fi', 'Fibre internet in every room and around the hotel.'),
    Facility(Icons.local_parking, 'Free parking', '20 covered slots for guests, first come, first served.'),
    Facility(Icons.flight, 'Airport transfers', 'From NAIA for ₱1,200 each way. Book with the front desk a day ahead.'),
    Facility(Icons.fitness_center, 'Fitness room', 'Open 24 hours with your room key.'),
    Facility(Icons.local_laundry_service, 'Laundry', 'Same-day service if handed in before 10 AM.'),
    Facility(Icons.elevator, 'Lift to every floor', 'Step-free entrance and one accessible room on the ground floor.'),
  ],
  gettingHere: [
    'About 15 minutes from NAIA Terminal 3 by car, longer at rush hour',
    'A 5-minute walk to the bay walk and the sunset',
    'Grab and taxis can drop off at the main entrance on Seaside Avenue',
  ],
  policies: [
    TextPair('Check-in and check-out',
        'Check-in is from $checkInTime and check-out is by $checkOutTime. Early check-in and late check-out depend on availability; ask the front desk. Late check-out until 3 PM is half a night\'s rate.'),
    TextPair('What to bring',
        'A valid government-issued ID or passport for the person named on the booking. We may also ask to see the card or account used to pay. To check in faster, you can upload the ID before you arrive.'),
    TextPair('Cancellation and changes',
        "Flexible rates are free to cancel or change dates up to 48 hours before check-in. After that, the first night is kept and the rest is refunded. Non-refundable rates can't be refunded or changed online. Refunds go back to the original payment method within 5 to 10 banking days."),
    TextPair('Payment and prices',
        'Online bookings are paid in full when you book, by GCash, Maya, GrabPay, QR Ph or card. Prices are in Philippine pesos and include 12% VAT and service charge. Your room is held for 15 minutes while you pay.'),
    TextPair('Children and extra beds',
        'Children under 7 stay free when using existing beds. Extra beds are ₱800 a night, and only fit in the Deluxe King and Family Suite.'),
    TextPair('Pets and smoking',
        "Pets aren't allowed, except service animals. The whole building is non-smoking; there is a smoking area beside the car park. A ₱3,000 cleaning fee applies if anyone smokes in a room."),
    TextPair('Quiet hours', '10 PM to 7 AM. Please keep music and calls low in the corridors and on the roof.'),
  ],
  faqs: [
    TextPair('Can I pay when I arrive instead?',
        "Online bookings are paid when you book, so your room is guaranteed. If you'd rather pay at the hotel, call the front desk and they can book you in as a walk-in, subject to availability."),
    TextPair("What happens if I don't finish paying?",
        "We hold the room for 15 minutes. If payment doesn't come through by then, the room is released and nothing is charged. You can book again any time."),
    TextPair('Can I change my dates?',
        "Yes, on flexible rates. Open the booking in My stays and choose Change dates, up to 48 hours before check-in. You'll see the new price before you confirm. For non-refundable rates, call the front desk."),
    TextPair('Can I send my ID before I arrive?',
        "Yes. Open your booking in My stays and upload a photo of your ID. Only the front desk can see it, and it's deleted once they've checked it."),
    TextPair('Is breakfast included?',
        "Only on rates that say so, like Flexible with breakfast. Otherwise breakfast in the café is ₱450 a person."),
    TextPair('Where do I find my booking?',
        'Open My stays. Each confirmed booking has a QR code to show at the front desk, and a receipt you can save as a PDF.'),
    TextPair("I'm arriving late at night. Is that OK?",
        'Yes. The front desk is open 24 hours. Tell us your arrival time when you book so we know to expect you.'),
  ],
  arrivalTimes: {
    'not_sure': "I'm not sure yet",
    'before_2pm': 'Before 2 PM (early check-in request)',
    '2pm_4pm': '2 PM to 4 PM',
    '4pm_6pm': '4 PM to 6 PM',
    '6pm_8pm': '6 PM to 8 PM',
    '8pm_10pm': '8 PM to 10 PM',
    'after_10pm': 'After 10 PM',
  },
  requestIdeas: ['High floor', 'Quiet room', 'Extra pillows', 'Baby cot', 'Celebrating something'],
);

const _fil = HotelContent(
  aboutHeading: 'Maliit na hotel sa tabi ng look: labindalawang kuwarto at malawak na tanaw sa kanluran',
  about: [
    'Itinayo namin ang $hotelName para sa mga gustong malapit sa lungsod pero malayo sa ingay. Nakaharap sa dagat ang bawat kuwarto, at ang mga bintanang capiz sa lobby ay ang mismong mga bintanang nakasabit dito noong unang itinayo ang bahay.',
    'Nagsisimula ang umaga sa kape at pandesal sa café. Sa gabi, umakyat sa rooftop at panoorin ang paglubog ng araw sa likod ng look, bandang alas-sais.',
  ],
  facts: [
    TextPair('Check-in', 'Mula $checkInTime'),
    TextPair('Check-out', 'Hanggang $checkOutTime'),
    TextPair('Front desk', 'Bukas 24 oras'),
    TextPair('Mga kuwarto', '12 kuwarto sa 3 palapag, bawal manigarilyo sa lahat'),
  ],
  facilities: [
    Facility(Icons.pool, 'Rooftop pool', 'Bukas 7 AM hanggang 9 PM. May tuwalya sa pool desk.'),
    Facility(Icons.restaurant, 'Café at restawran',
        'Almusal 6:30 hanggang 10:30 AM, hapunan hanggang 10 PM. ₱450 ang almusal kung hindi ito kasama sa rate mo.'),
    Facility(Icons.wifi, 'Libreng Wi-Fi', 'Fibre internet sa bawat kuwarto at sa buong hotel.'),
    Facility(Icons.local_parking, 'Libreng paradahan', '20 may-bubong na slot para sa mga bisita, paunahan.'),
    Facility(Icons.flight, 'Sundo mula sa airport', 'Mula NAIA, ₱1,200 bawat biyahe. Mag-book sa front desk isang araw bago.'),
    Facility(Icons.fitness_center, 'Fitness room', 'Bukas 24 oras gamit ang room key mo.'),
    Facility(Icons.local_laundry_service, 'Laundry', 'Same-day kung maibibigay bago mag-10 AM.'),
    Facility(Icons.elevator, 'Elevator sa bawat palapag',
        'Walang baitang sa pasukan, at may isang accessible na kuwarto sa ground floor.'),
  ],
  gettingHere: [
    'Mga 15 minuto mula NAIA Terminal 3 sakay ng kotse, mas matagal kapag rush hour',
    '5 minutong lakad papunta sa bay walk at sa paglubog ng araw',
    'Puwedeng magbaba ang Grab at taxi sa main entrance sa Seaside Avenue',
  ],
  policies: [
    TextPair('Check-in at check-out',
        'Ang check-in ay mula $checkInTime at ang check-out ay hanggang $checkOutTime. Depende sa availability ang maagang check-in at late check-out; magtanong sa front desk. Kalahati ng rate ng isang gabi ang late check-out hanggang 3 PM.'),
    TextPair('Mga dapat dalhin',
        'Valid na government ID o pasaporte ng taong nakapangalan sa booking. Maaari rin naming hingin na makita ang card o account na ipinambayad. Para mas mabilis ang check-in, puwede mong i-upload ang ID bago ka dumating.'),
    TextPair('Pagkansela at pagpapalit',
        'Libre ang pagkansela o pagpapalit ng petsa sa flexible rate hanggang 48 oras bago ang check-in. Pagkatapos noon, hindi na ibabalik ang bayad sa unang gabi at ire-refund ang natitira. Walang refund at hindi mapapalitan online ang non-refundable rate. Ibinabalik ang refund sa orihinal na paraan ng pagbayad sa loob ng 5 hanggang 10 banking day.'),
    TextPair('Bayad at mga presyo',
        'Buong bayad kapag nag-book online, sa GCash, Maya, GrabPay, QR Ph o card. Nasa piso ang mga presyo at kasama na ang 12% VAT at service charge. Ihahawak namin ang kuwarto mo nang 15 minuto habang nagbabayad ka.'),
    TextPair('Mga bata at extra bed',
        'Libre ang mga batang wala pang 7 taong gulang kung gagamit ng mga kasalukuyang kama. ₱800 bawat gabi ang extra bed, at kasya lang ito sa Deluxe King at Family Suite.'),
    TextPair('Alagang hayop at paninigarilyo',
        'Bawal ang alagang hayop, maliban sa service animal. Bawal manigarilyo sa buong gusali; may smoking area sa tabi ng paradahan. May ₱3,000 na cleaning fee kapag may nanigarilyo sa kuwarto.'),
    TextPair('Oras ng katahimikan', '10 PM hanggang 7 AM. Pakihinaan ang musika at mga tawag sa mga pasilyo at sa rooftop.'),
  ],
  faqs: [
    TextPair('Puwede bang sa pagdating na lang magbayad?',
        'Binabayaran ang online booking sa oras ng pag-book para siguradong sa iyo ang kuwarto. Kung gusto mong sa hotel magbayad, tumawag sa front desk at ipapa-book ka nila bilang walk-in, depende sa availability.'),
    TextPair('Paano kung hindi ko natapos ang pagbayad?',
        'Ihahawak namin ang kuwarto nang 15 minuto. Kung hindi pumasok ang bayad sa loob ng oras na iyon, bibitawan ang kuwarto at walang sisingilin. Puwede kang mag-book ulit kahit kailan.'),
    TextPair('Puwede ko bang palitan ang mga petsa?',
        'Oo, kung flexible rate. Buksan ang booking sa Mga booking ko at piliin ang Palitan ang petsa, hanggang 48 oras bago ang check-in. Makikita mo muna ang bagong presyo bago mo kumpirmahin. Kung non-refundable rate, tumawag sa front desk.'),
    TextPair('Puwede ko bang ipadala ang ID ko bago dumating?',
        'Oo. Buksan ang booking mo sa Mga booking ko at i-upload ang litrato ng ID mo. Ang front desk lang ang makakakita nito, at buburahin ito kapag na-check na nila.'),
    TextPair('Kasama ba ang almusal?',
        'Sa mga rate lang na nagsasabing kasama ito, gaya ng Flexible with breakfast. Kung hindi, ₱450 bawat tao ang almusal sa café.'),
    TextPair('Saan ko makikita ang booking ko?',
        'Buksan ang Mga booking ko. May QR code ang bawat kumpirmadong booking na ipapakita sa front desk, at resibong puwedeng i-save bilang PDF.'),
    TextPair('Gabi na ako darating. Ayos lang ba?',
        'Oo. Bukas 24 oras ang front desk. Sabihin sa amin ang oras ng pagdating mo kapag nag-book ka para maasahan ka namin.'),
  ],
  arrivalTimes: {
    'not_sure': 'Hindi pa ako sigurado',
    'before_2pm': 'Bago mag-2 PM (hiling na maagang check-in)',
    '2pm_4pm': '2 PM hanggang 4 PM',
    '4pm_6pm': '4 PM hanggang 6 PM',
    '6pm_8pm': '6 PM hanggang 8 PM',
    '8pm_10pm': '8 PM hanggang 10 PM',
    'after_10pm': 'Pagkalipas ng 10 PM',
  },
  requestIdeas: ['Mataas na palapag', 'Tahimik na kuwarto', 'Dagdag na unan', 'Kuna para sa sanggol', 'May ipinagdiriwang'],
);

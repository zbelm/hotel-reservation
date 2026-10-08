// Everything guests read about the hotel lives here, in English and Filipino, so it can be
// changed in one place. This is sample content for "Sample Bay Hotel": replace it with your
// hotel's real details before taking real bookings (facilities, prices, distances and rules
// are placeholders). Keep the two languages saying the same thing.

export const HOTEL = {
  name: process.env.NEXT_PUBLIC_HOTEL_NAME ?? "Sample Bay Hotel",
  address: process.env.NEXT_PUBLIC_HOTEL_ADDRESS ?? "123 Seaside Avenue, Pasay City, Metro Manila",
  phone: process.env.NEXT_PUBLIC_HOTEL_PHONE ?? "+63 2 8123 4567",
  email: process.env.NEXT_PUBLIC_HOTEL_EMAIL ?? "stay@samplebayhotel.ph",
  checkIn: "2:00 PM",
  checkOut: "12:00 PM",
  // Map pin (latitude, longitude)
  lat: 14.5352,
  lng: 120.9822,
};

export type FacilityIcon = "pool" | "food" | "wifi" | "car" | "plane" | "gym" | "laundry" | "lift";
export type Facility = { name: string; detail: string; icon: FacilityIcon };
export type Policy = { title: string; body: string };
export type Faq = { q: string; a: string };
export type ArrivalValue = "not_sure" | "before_2pm" | "2pm_4pm" | "4pm_6pm" | "6pm_8pm" | "8pm_10pm" | "after_10pm";

export type HotelContent = {
  about: { heading: string; body: string[]; facts: { term: string; detail: string }[] };
  facilities: Facility[];
  gettingHere: string[];
  policies: Policy[];
  faqs: Faq[];
  arrivalTimes: { value: ArrivalValue; label: string }[];
  requestIdeas: string[];
};

const en: HotelContent = {
  about: {
    heading: "A small hotel on the bay, twelve rooms and a long view west",
    body: [
      "We built Sample Bay Hotel for people who want the city close but not loud. Every room faces the water, and the capiz shell windows in the lobby are the same ones that hung here when the house was first built.",
      "Mornings start with coffee and pandesal in the café. Evenings are for the rooftop, where the sun drops behind the bay a little after six.",
    ],
    facts: [
      { term: "Check-in", detail: `From ${HOTEL.checkIn}` },
      { term: "Check-out", detail: `By ${HOTEL.checkOut}` },
      { term: "Front desk", detail: "Open 24 hours" },
      { term: "Rooms", detail: "12 rooms on 3 floors, all non-smoking" },
    ],
  },
  facilities: [
    { name: "Rooftop pool", detail: "Open 7 AM to 9 PM. Towels at the pool desk.", icon: "pool" },
    { name: "Café and restaurant", detail: "Breakfast 6:30 to 10:30 AM, dinner until 10 PM. Breakfast is ₱450 if your rate doesn't include it.", icon: "food" },
    { name: "Free Wi-Fi", detail: "Fibre internet in every room and around the hotel.", icon: "wifi" },
    { name: "Free parking", detail: "20 covered slots for guests, first come, first served.", icon: "car" },
    { name: "Airport transfers", detail: "From NAIA for ₱1,200 each way. Book with the front desk a day ahead.", icon: "plane" },
    { name: "Fitness room", detail: "Open 24 hours with your room key.", icon: "gym" },
    { name: "Laundry", detail: "Same-day service if handed in before 10 AM.", icon: "laundry" },
    { name: "Lift to every floor", detail: "Step-free entrance and one accessible room on the ground floor.", icon: "lift" },
  ],
  gettingHere: [
    "About 15 minutes from NAIA Terminal 3 by car, longer at rush hour",
    "A 5-minute walk to the bay walk and the sunset",
    "Grab and taxis can drop off at the main entrance on Seaside Avenue",
  ],
  policies: [
    {
      title: "Check-in and check-out",
      body: `Check-in is from ${HOTEL.checkIn} and check-out is by ${HOTEL.checkOut}. Early check-in and late check-out depend on availability; ask the front desk. Late check-out until 3 PM is half a night's rate.`,
    },
    {
      title: "What to bring",
      body: "A valid government-issued ID or passport for the person named on the booking. We may also ask to see the card or account used to pay. To check in faster, you can upload the ID before you arrive.",
    },
    {
      title: "Cancellation and changes",
      body: "Flexible rates are free to cancel or change dates up to 48 hours before check-in. After that, the first night is kept and the rest is refunded. Non-refundable rates can't be refunded or changed online. Refunds go back to the original payment method within 5 to 10 banking days.",
    },
    {
      title: "Payment and prices",
      body: "Online bookings are paid in full when you book, by GCash, Maya, GrabPay, QR Ph or card. Prices are in Philippine pesos and include 12% VAT and service charge. Your room is held for 15 minutes while you pay.",
    },
    {
      title: "Children and extra beds",
      body: "Children under 7 stay free when using existing beds. Extra beds are ₱800 a night, and only fit in the Deluxe King and Family Suite.",
    },
    {
      title: "Pets and smoking",
      body: "Pets aren't allowed, except service animals. The whole building is non-smoking; there is a smoking area beside the car park. A ₱3,000 cleaning fee applies if anyone smokes in a room.",
    },
    {
      title: "Quiet hours",
      body: "10 PM to 7 AM. Please keep music and calls low in the corridors and on the roof.",
    },
  ],
  faqs: [
    {
      q: "Can I pay when I arrive instead?",
      a: "Online bookings are paid when you book, so your room is guaranteed. If you'd rather pay at the hotel, call the front desk and they can book you in as a walk-in, subject to availability.",
    },
    {
      q: "What happens if I don't finish paying?",
      a: "We hold the room for 15 minutes. If payment doesn't come through by then, the room is released and nothing is charged. You can book again any time.",
    },
    {
      q: "Can I change my dates?",
      a: "Yes, on flexible rates. Open the booking in My stays and choose Change dates, up to 48 hours before check-in. You'll see the new price before you confirm. For non-refundable rates, call the front desk.",
    },
    {
      q: "Can I send my ID before I arrive?",
      a: "Yes. Open your booking in My stays and upload a photo of your ID. Only the front desk can see it, and it's deleted once they've checked it.",
    },
    {
      q: "Is breakfast included?",
      a: "Only on rates that say so, like Flexible with breakfast. Otherwise breakfast in the café is ₱450 a person.",
    },
    {
      q: "Where do I find my booking?",
      a: "Sign in and open My stays. Each confirmed booking has a QR code to show at the front desk, and a receipt you can download.",
    },
    {
      q: "I'm arriving late at night. Is that OK?",
      a: "Yes. The front desk is open 24 hours. Tell us your arrival time when you book so we know to expect you.",
    },
  ],
  arrivalTimes: [
    { value: "not_sure", label: "I'm not sure yet" },
    { value: "before_2pm", label: "Before 2 PM (early check-in request)" },
    { value: "2pm_4pm", label: "2 PM to 4 PM" },
    { value: "4pm_6pm", label: "4 PM to 6 PM" },
    { value: "6pm_8pm", label: "6 PM to 8 PM" },
    { value: "8pm_10pm", label: "8 PM to 10 PM" },
    { value: "after_10pm", label: "After 10 PM" },
  ],
  requestIdeas: ["High floor", "Quiet room", "Extra pillows", "Baby cot", "Celebrating something"],
};

const fil: HotelContent = {
  about: {
    heading: "Maliit na hotel sa tabi ng look: labindalawang kuwarto at malawak na tanaw sa kanluran",
    body: [
      "Itinayo namin ang Sample Bay Hotel para sa mga gustong malapit sa lungsod pero malayo sa ingay. Nakaharap sa dagat ang bawat kuwarto, at ang mga bintanang capiz sa lobby ay ang mismong mga bintanang nakasabit dito noong unang itinayo ang bahay.",
      "Nagsisimula ang umaga sa kape at pandesal sa café. Sa gabi, umakyat sa rooftop at panoorin ang paglubog ng araw sa likod ng look, bandang alas-sais.",
    ],
    facts: [
      { term: "Check-in", detail: `Mula ${HOTEL.checkIn}` },
      { term: "Check-out", detail: `Hanggang ${HOTEL.checkOut}` },
      { term: "Front desk", detail: "Bukas 24 oras" },
      { term: "Mga kuwarto", detail: "12 kuwarto sa 3 palapag, bawal manigarilyo sa lahat" },
    ],
  },
  facilities: [
    { name: "Rooftop pool", detail: "Bukas 7 AM hanggang 9 PM. May tuwalya sa pool desk.", icon: "pool" },
    { name: "Café at restawran", detail: "Almusal 6:30 hanggang 10:30 AM, hapunan hanggang 10 PM. ₱450 ang almusal kung hindi ito kasama sa rate mo.", icon: "food" },
    { name: "Libreng Wi-Fi", detail: "Fibre internet sa bawat kuwarto at sa buong hotel.", icon: "wifi" },
    { name: "Libreng paradahan", detail: "20 may-bubong na slot para sa mga bisita, paunahan.", icon: "car" },
    { name: "Sundo mula sa airport", detail: "Mula NAIA, ₱1,200 bawat biyahe. Mag-book sa front desk isang araw bago.", icon: "plane" },
    { name: "Fitness room", detail: "Bukas 24 oras gamit ang room key mo.", icon: "gym" },
    { name: "Laundry", detail: "Same-day kung maibibigay bago mag-10 AM.", icon: "laundry" },
    { name: "Elevator sa bawat palapag", detail: "Walang baitang sa pasukan, at may isang accessible na kuwarto sa ground floor.", icon: "lift" },
  ],
  gettingHere: [
    "Mga 15 minuto mula NAIA Terminal 3 sakay ng kotse, mas matagal kapag rush hour",
    "5 minutong lakad papunta sa bay walk at sa paglubog ng araw",
    "Puwedeng magbaba ang Grab at taxi sa main entrance sa Seaside Avenue",
  ],
  policies: [
    {
      title: "Check-in at check-out",
      body: `Ang check-in ay mula ${HOTEL.checkIn} at ang check-out ay hanggang ${HOTEL.checkOut}. Depende sa availability ang maagang check-in at late check-out; magtanong sa front desk. Kalahati ng rate ng isang gabi ang late check-out hanggang 3 PM.`,
    },
    {
      title: "Mga dapat dalhin",
      body: "Valid na government ID o pasaporte ng taong nakapangalan sa booking. Maaari rin naming hingin na makita ang card o account na ipinambayad. Para mas mabilis ang check-in, puwede mong i-upload ang ID bago ka dumating.",
    },
    {
      title: "Pagkansela at pagpapalit",
      body: "Libre ang pagkansela o pagpapalit ng petsa sa flexible rate hanggang 48 oras bago ang check-in. Pagkatapos noon, hindi na ibabalik ang bayad sa unang gabi at ire-refund ang natitira. Walang refund at hindi mapapalitan online ang non-refundable rate. Ibinabalik ang refund sa orihinal na paraan ng pagbayad sa loob ng 5 hanggang 10 banking day.",
    },
    {
      title: "Bayad at mga presyo",
      body: "Buong bayad kapag nag-book online, sa GCash, Maya, GrabPay, QR Ph o card. Nasa piso ang mga presyo at kasama na ang 12% VAT at service charge. Ihahawak namin ang kuwarto mo nang 15 minuto habang nagbabayad ka.",
    },
    {
      title: "Mga bata at extra bed",
      body: "Libre ang mga batang wala pang 7 taong gulang kung gagamit ng mga kasalukuyang kama. ₱800 bawat gabi ang extra bed, at kasya lang ito sa Deluxe King at Family Suite.",
    },
    {
      title: "Alagang hayop at paninigarilyo",
      body: "Bawal ang alagang hayop, maliban sa service animal. Bawal manigarilyo sa buong gusali; may smoking area sa tabi ng paradahan. May ₱3,000 na cleaning fee kapag may nanigarilyo sa kuwarto.",
    },
    {
      title: "Oras ng katahimikan",
      body: "10 PM hanggang 7 AM. Pakihinaan ang musika at mga tawag sa mga pasilyo at sa rooftop.",
    },
  ],
  faqs: [
    {
      q: "Puwede bang sa pagdating na lang magbayad?",
      a: "Binabayaran ang online booking sa oras ng pag-book para siguradong sa iyo ang kuwarto. Kung gusto mong sa hotel magbayad, tumawag sa front desk at ipapa-book ka nila bilang walk-in, depende sa availability.",
    },
    {
      q: "Paano kung hindi ko natapos ang pagbayad?",
      a: "Ihahawak namin ang kuwarto nang 15 minuto. Kung hindi pumasok ang bayad sa loob ng oras na iyon, bibitawan ang kuwarto at walang sisingilin. Puwede kang mag-book ulit kahit kailan.",
    },
    {
      q: "Puwede ko bang palitan ang mga petsa?",
      a: "Oo, kung flexible rate. Buksan ang booking sa My stays at piliin ang Palitan ang petsa, hanggang 48 oras bago ang check-in. Makikita mo muna ang bagong presyo bago mo kumpirmahin. Kung non-refundable rate, tumawag sa front desk.",
    },
    {
      q: "Puwede ko bang ipadala ang ID ko bago dumating?",
      a: "Oo. Buksan ang booking mo sa My stays at i-upload ang litrato ng ID mo. Ang front desk lang ang makakakita nito, at buburahin ito kapag na-check na nila.",
    },
    {
      q: "Kasama ba ang almusal?",
      a: "Sa mga rate lang na nagsasabing kasama ito, gaya ng Flexible with breakfast. Kung hindi, ₱450 bawat tao ang almusal sa café.",
    },
    {
      q: "Saan ko makikita ang booking ko?",
      a: "Mag-sign in at buksan ang My stays. May QR code ang bawat kumpirmadong booking na ipapakita sa front desk, at resibong puwedeng i-download.",
    },
    {
      q: "Gabi na ako darating. Ayos lang ba?",
      a: "Oo. Bukas 24 oras ang front desk. Sabihin sa amin ang oras ng pagdating mo kapag nag-book ka para maasahan ka namin.",
    },
  ],
  arrivalTimes: [
    { value: "not_sure", label: "Hindi pa ako sigurado" },
    { value: "before_2pm", label: "Bago mag-2 PM (hiling na maagang check-in)" },
    { value: "2pm_4pm", label: "2 PM hanggang 4 PM" },
    { value: "4pm_6pm", label: "4 PM hanggang 6 PM" },
    { value: "6pm_8pm", label: "6 PM hanggang 8 PM" },
    { value: "8pm_10pm", label: "8 PM hanggang 10 PM" },
    { value: "after_10pm", label: "Pagkalipas ng 10 PM" },
  ],
  requestIdeas: ["Mataas na palapag", "Tahimik na kuwarto", "Dagdag na unan", "Kuna para sa sanggol", "May ipinagdiriwang"],
};

export const content: Record<"en" | "fil", HotelContent> = { en, fil };

// Staff screens are in English
export function arrivalLabel(value: string | null | undefined, lang: "en" | "fil" = "en"): string | null {
  return content[lang].arrivalTimes.find((a) => a.value === value)?.label ?? null;
}

export const mapsUrl = `https://www.google.com/maps/search/?api=1&query=${HOTEL.lat},${HOTEL.lng}`;
export const mapEmbedUrl = (() => {
  const d = 0.008;
  const bbox = [HOTEL.lng - d * 1.6, HOTEL.lat - d, HOTEL.lng + d * 1.6, HOTEL.lat + d].join(",");
  return `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&layer=mapnik&marker=${HOTEL.lat},${HOTEL.lng}`;
})();

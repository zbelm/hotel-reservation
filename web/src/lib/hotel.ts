// Everything guests read about the hotel lives here, so it can be changed in one place.
// This is sample content for "Sample Bay Hotel": replace it with your hotel's real details
// before taking real bookings (facilities, prices, distances and rules are placeholders).

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

export const ABOUT = {
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
};

export type Facility = { name: string; detail: string; icon: FacilityIcon };
export type FacilityIcon = "pool" | "food" | "wifi" | "car" | "plane" | "gym" | "laundry" | "lift";

export const FACILITIES: Facility[] = [
  { name: "Rooftop pool", detail: "Open 7 AM to 9 PM. Towels at the pool desk.", icon: "pool" },
  { name: "Café and restaurant", detail: "Breakfast 6:30 to 10:30 AM, dinner until 10 PM. Breakfast is ₱450 if your rate doesn't include it.", icon: "food" },
  { name: "Free Wi-Fi", detail: "Fibre internet in every room and around the hotel.", icon: "wifi" },
  { name: "Free parking", detail: "20 covered slots for guests, first come, first served.", icon: "car" },
  { name: "Airport transfers", detail: "From NAIA for ₱1,200 each way. Book with the front desk a day ahead.", icon: "plane" },
  { name: "Fitness room", detail: "Open 24 hours with your room key.", icon: "gym" },
  { name: "Laundry", detail: "Same-day service if handed in before 10 AM.", icon: "laundry" },
  { name: "Lift to every floor", detail: "Step-free entrance and one accessible room on the ground floor.", icon: "lift" },
];

export const GETTING_HERE = [
  "About 15 minutes from NAIA Terminal 3 by car, longer at rush hour",
  "A 5-minute walk to the bay walk and the sunset",
  "Grab and taxis can drop off at the main entrance on Seaside Avenue",
];

export type Policy = { title: string; body: string };

export const POLICIES: Policy[] = [
  {
    title: "Check-in and check-out",
    body: `Check-in is from ${HOTEL.checkIn} and check-out is by ${HOTEL.checkOut}. Early check-in and late check-out depend on availability; ask the front desk. Late check-out until 3 PM is half a night's rate.`,
  },
  {
    title: "What to bring",
    body: "A valid government-issued ID or passport for the person named on the booking. We may also ask to see the card or account used to pay.",
  },
  {
    title: "Cancellation",
    body: "Flexible rates are free to cancel up to 48 hours before check-in. After that, the first night is kept and the rest is refunded. Non-refundable rates can't be refunded. Refunds go back to the original payment method within 5 to 10 banking days.",
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
];

export type Faq = { q: string; a: string };

export const FAQS: Faq[] = [
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
    a: "On a flexible rate, cancel for free (up to 48 hours before check-in) and book the new dates. On a non-refundable rate, call the front desk and we'll see what we can do.",
  },
  {
    q: "Is breakfast included?",
    a: "Only on rates that say so, like Flexible with breakfast. Otherwise breakfast in the café is ₱450 a person.",
  },
  {
    q: "Where do I find my booking?",
    a: "Sign in and open My stays. Each confirmed booking has a QR code; show it at the front desk to check in quickly.",
  },
  {
    q: "I'm arriving late at night. Is that OK?",
    a: "Yes. The front desk is open 24 hours. Tell us your arrival time when you book so we know to expect you.",
  },
];

export const ARRIVAL_TIMES = [
  { value: "not_sure", label: "I'm not sure yet" },
  { value: "before_2pm", label: "Before 2 PM (early check-in request)" },
  { value: "2pm_4pm", label: "2 PM to 4 PM" },
  { value: "4pm_6pm", label: "4 PM to 6 PM" },
  { value: "6pm_8pm", label: "6 PM to 8 PM" },
  { value: "8pm_10pm", label: "8 PM to 10 PM" },
  { value: "after_10pm", label: "After 10 PM" },
] as const;

export function arrivalLabel(value: string | null | undefined): string | null {
  return ARRIVAL_TIMES.find((a) => a.value === value)?.label ?? null;
}

export const REQUEST_IDEAS = ["High floor", "Quiet room", "Extra pillows", "Baby cot", "Celebrating something"];

export const mapsUrl = `https://www.google.com/maps/search/?api=1&query=${HOTEL.lat},${HOTEL.lng}`;
export const mapEmbedUrl = (() => {
  const d = 0.008;
  const bbox = [HOTEL.lng - d * 1.6, HOTEL.lat - d, HOTEL.lng + d * 1.6, HOTEL.lat + d].join(",");
  return `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&layer=mapnik&marker=${HOTEL.lat},${HOTEL.lng}`;
})();

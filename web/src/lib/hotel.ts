// Shown in the header, footer and emails. Set these in Vercel's environment variables.
export const HOTEL = {
  name: process.env.NEXT_PUBLIC_HOTEL_NAME ?? "Sample Bay Hotel",
  address: process.env.NEXT_PUBLIC_HOTEL_ADDRESS ?? "Taguig City, Metro Manila",
  phone: process.env.NEXT_PUBLIC_HOTEL_PHONE ?? "+63 2 8123 4567",
  checkIn: "2:00 PM",
  checkOut: "12:00 PM",
};

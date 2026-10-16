// Guests book; admins run the staff portal. There is one staff role.
export type Role = "guest" | "admin";

export type Profile = {
  id: string;
  full_name: string | null;
  phone: string | null;
  role: Role;
};

export type SearchResult = {
  room_type_id: string;
  name: string;
  description: string | null;
  max_adults: number;
  max_children: number;
  bed_type: string | null;
  size_sqm: number | null;
  amenities: string[];
  photos: string[];
  available: number;
  nights: number;
  lowest_total: number;
  lowest_nightly: number;
};

export type RoomType = {
  id: string;
  name: string;
  description: string | null;
  description_fil?: string | null;
  max_adults: number;
  max_children: number;
  bed_type: string | null;
  size_sqm: number | null;
  amenities: string[];
  photos: string[];
  base_price: number;
};

export type Offer = {
  rate_plan_id: string;
  name: string;
  description: string | null;
  refundable: boolean;
  free_cancel_hours: number;
  includes_breakfast: boolean;
  min_stay: number;
  bookable: boolean;
  total: number;
  nightly: { date: string; price: number }[];
  available: number;
};

export type BookingStatus =
  | "held" | "confirmed" | "checked_out" | "cancelled" | "no_show" | "expired"; // checked_out = stay completed

export type Booking = {
  id: string;
  code: string;
  guest_id: string | null;
  guest_name: string;
  guest_email: string;
  guest_phone: string | null;
  check_in: string;
  check_out: string;
  adults: number;
  children: number;
  status: BookingStatus;
  hold_expires_at: string | null;
  total: number;
  amount_paid: number;
  refund_due: number;
  currency: string;
  source: string;
  special_requests: string | null;
  arrival_time: string | null;
  policies_accepted_at: string | null;
  payment_option?: "online" | "pay_at_hotel" | "front_desk";
  room_id?: string | null;     // the room assigned to a confirmed booking
  arrived_at?: string | null;  // set when staff confirm the guest arrived
  room?: { number: string } | null; // only with STAFF_BOOKING_SELECT
  created_at: string;
  booking_rooms?: {
    id: string;
    room_type_id: string;
    nightly_prices: { date: string; price: number }[];
    room_types: { name: string } | null;
    rate_plans: { name: string; refundable: boolean; free_cancel_hours: number; includes_breakfast: boolean } | null;
  }[];
};

export type RoomStatus = "vacant_clean" | "dirty" | "cleaning" | "out_of_order";

export type Room = {
  id: string;
  number: string;
  floor: number | null;
  status: RoomStatus;
  room_type_id: string;
  room_types: { name: string } | null;
};

export const BOOKING_SELECT =
  "*, booking_rooms(id, room_type_id, nightly_prices, room_types(name), rate_plans(name, refundable, free_cancel_hours, includes_breakfast))";

// Staff views also need the assigned room (the hint names the foreign key, since
// housekeeping_tasks links bookings and rooms too)
export const STAFF_BOOKING_SELECT = `${BOOKING_SELECT}, room:rooms!bookings_room_id_fkey(number)`;

// What the Rooms board shows for each room right now (staff_room_board)
export type Occupancy = "occupied" | "leaving_soon" | "not_arrived" | "empty" | "out_of_order";

export type BoardRoom = {
  room_id: string;
  number: string;
  floor: number | null;
  room_type_id: string;
  room_type: string;
  room_status: RoomStatus;
  occupancy: Occupancy;
  booking_id: string | null;
  guest_name: string | null;
  check_in: string | null;
  check_out: string | null;
  arrived_at: string | null;
};

export type Review = {
  id: string;
  booking_id: string;
  room_type_id: string | null;
  display_name: string;
  rating: number;
  body: string | null;
  is_published: boolean;
  stayed_on: string;
  created_at: string;
};

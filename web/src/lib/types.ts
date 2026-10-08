export type Role = "guest" | "front_desk" | "housekeeping" | "manager" | "admin";

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
  | "held" | "confirmed" | "checked_in" | "checked_out" | "cancelled" | "no_show" | "expired";

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
  id_document_path?: string | null;
  id_uploaded_at?: string | null;
  id_verified_at?: string | null;
  created_at: string;
  booking_rooms?: {
    id: string;
    room_type_id: string;
    room_id: string | null;
    nightly_prices: { date: string; price: number }[];
    room_types: { name: string } | null;
    rate_plans: { name: string; refundable: boolean; free_cancel_hours: number; includes_breakfast: boolean } | null;
    rooms: { number: string } | null;
  }[];
};

export type RoomStatus = "vacant_clean" | "dirty" | "cleaning" | "occupied" | "out_of_order";

export type Room = {
  id: string;
  number: string;
  floor: number | null;
  status: RoomStatus;
  room_type_id: string;
  room_types: { name: string } | null;
};

export const BOOKING_SELECT =
  "*, booking_rooms(id, room_type_id, room_id, nightly_prices, room_types(name), rate_plans(name, refundable, free_cancel_hours, includes_breakfast), rooms(number))";

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

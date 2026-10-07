import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get db => Supabase.instance.client;

const bookingSelect =
    '*, booking_rooms(id, room_type_id, room_id, nightly_prices, room_types(name), rate_plans(name, refundable, free_cancel_hours, includes_breakfast), rooms(number))';

/// Turns any Supabase error into a sentence a guest can read.
String errorText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return '${d['error']}';
    return e.reasonPhrase ?? 'Something went wrong';
  }
  return 'Something went wrong. Check your connection and try again.';
}

/// Starts a PayMongo checkout for a held booking and returns its URL.
Future<String> createCheckout(String bookingId) async {
  final res = await db.functions.invoke('create-checkout', body: {'booking_id': bookingId});
  final data = res.data;
  if (data is Map && data['checkout_url'] is String) return data['checkout_url'] as String;
  throw Exception('Could not start payment');
}

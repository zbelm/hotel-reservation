// Pass these when you run or build the app, for example:
//   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const hotelName = String.fromEnvironment('HOTEL_NAME', defaultValue: 'Sample Bay Hotel');

const checkInTime = '2:00 PM';
const checkOutTime = '12:00 PM';

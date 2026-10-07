// The live project's public settings. The publishable key is safe to ship in an app:
// the database's security rules decide what each user can see and do.
// To point at a different Supabase project, override them when you build:
//   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://jmiskdtkbyrmcgbtltme.supabase.co');
const supabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_cic6H4sfuz6_lzv44ZBsAw_J2yluzF8');
const hotelName = String.fromEnvironment('HOTEL_NAME', defaultValue: 'Sample Bay Hotel');

/// Where the sign-in email link sends the guest. Android opens the app for this address
/// (see android/app/src/main/AndroidManifest.xml); it is also listed under
/// Supabase → Authentication → URL Configuration → Redirect URLs.
const authRedirect = 'com.samplebayhotel.app://login-callback';

const checkInTime = '2:00 PM';
const checkOutTime = '12:00 PM';

# Sample Bay Hotel guest app

Flutter app for guests: browse the hotel, pick dates on a calendar that shows nightly prices, book and pay, and manage stays (QR code, change dates, upload an ID before arrival, receipt as a PDF, review after check-out). English and Filipino, switched with the FIL / EN button.

See the main README (section "Flutter: the mobile app") for building and installing it.

| File | What's in it |
| --- | --- |
| `lib/hotel.dart` | Hotel text in both languages: about, facilities, house rules, FAQ, arrival times |
| `lib/i18n.dart` | Language switch; `tr('English', 'Filipino')` picks the text |
| `lib/price_calendar.dart` | Date picker with prices and full nights |
| `lib/screens/` | Book, Hotel, My stays and the screens they open |

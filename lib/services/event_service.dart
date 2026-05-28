import 'package:firebase_database/firebase_database.dart';

class EventService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref("events");

  Stream<DatabaseEvent> eventsStream() => _ref.onValue;

  Future<void> addEvent({
    required String title,
    required String category,
    required String date,
    required String time,
    required String location,
    required String description,
    required String registrationLink,
    required String bannerUrl,

    // ✅ NEW (for Home Feed name + verified)
    required String postedByName,
    required String postedByRole,
  }) async {
    final newRef = _ref.push();

    await newRef.set({
      "title": title,
      "category": category,
      "date": date,
      "time": time,
      "location": location,
      "description": description,
      "registrationLink": registrationLink,

      // banner
      "bannerUrl": bannerUrl,

      // posted by
      "postedByName": postedByName,
      "postedByRole": postedByRole,

      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteEvent(String eventId) async {
    await _ref.child(eventId).remove();
  }

  Future<void> deletePastEvents() async {
    final snapshot = await _ref.get();
    if (!snapshot.exists) return;

    final raw = snapshot.value;
    if (raw is! Map) return;

    final map = Map<dynamic, dynamic>.from(raw);

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (final entry in map.entries) {
      if (entry.value is! Map) continue;

      final eventData = Map<dynamic, dynamic>.from(entry.value);
      final dateStr = (eventData["date"] ?? "").toString();

      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;

      if (dt.isBefore(todayOnly)) {
        await _ref.child(entry.key.toString()).remove();
      }
    }
  }
}

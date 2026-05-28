import 'package:firebase_database/firebase_database.dart';

class StoryCleanupService {
  final DatabaseReference _storiesRef = FirebaseDatabase.instance.ref("stories");

  int _safeTime(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  bool _isExpired(int createdAtMs) {
    if (createdAtMs == 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - createdAtMs) > 24 * 60 * 60 * 1000; // 24 hrs
  }

  Future<void> deleteExpiredStories() async {
    final snap = await _storiesRef.get();
    final raw = snap.value;

    if (raw == null || raw is! Map) return;

    final map = Map<dynamic, dynamic>.from(raw);

    for (final entry in map.entries) {
      final storyId = entry.key.toString();
      if (entry.value is! Map) continue;

      final story = Map<String, dynamic>.from(entry.value as Map);
      final createdAt = _safeTime(story["createdAt"]);

      if (_isExpired(createdAt)) {
        // ✅ delete from firebase only
        await _storiesRef.child(storyId).remove();
      }
    }
  }
}

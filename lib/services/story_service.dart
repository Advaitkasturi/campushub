import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'cloudinary_service.dart';

class StoryService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref("stories");
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("users");

  Stream<DatabaseEvent> storyStream() => _ref.onValue;

  Future<Map<String, dynamic>> _getMyProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final snap = await _usersRef.child(uid).get();
    final data = snap.value;

    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  // ✅ Upload story image to cloudinary (uses unsigned upload)
  Future<String> uploadStoryToCloudinary({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return CloudinaryService.uploadImage(bytes: bytes, fileName: fileName);
  }

  Future<void> addStory({
    required String title,
    required String imageUrl,
    required String publicId, // (optional use later if you implement delete)
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Not logged in");

    final profile = await _getMyProfile();
    final name = (profile["name"] ?? "User").toString();
    final role = (profile["role"] ?? "student").toString();

    final newRef = _ref.push();

    await newRef.set({
      "id": newRef.key,
      "title": title,
      "imageUrl": imageUrl,
      "publicId": publicId,
      "postedBy": uid,
      "postedByName": name,
      "postedByRole": role,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
      "expiresAt":
          DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
    });
  }

  Future<void> deleteStoryById(String storyId) async {
    await _ref.child(storyId).remove();
  }
}

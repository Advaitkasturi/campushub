import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'cloudinary_service.dart';

class LostFoundService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref("lost_found");

  Stream<DatabaseEvent> lostFoundStream() => _ref.onValue;

  Future<void> addPost({
    required String type,
    required String title,
    required String desc,
    required String category,
    required String location,
    required String imageUrl,
    required String postedByUid,
    required String postedByName,
    required String postedByEmail,
    required String postedByPhone,
  }) async {
    final newRef = _ref.push();

    await newRef.set({
      "type": type,
      "title": title,
      "desc": desc,
      "category": category,
      "location": location,
      "imageUrl": imageUrl,
      "postedByUid": postedByUid,
      "postedByName": postedByName,
      "postedByEmail": postedByEmail,
      "postedByPhone": postedByPhone,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deletePost(String postId) async {
    await _ref.child(postId).remove();
  }

  Future<String> uploadImageToCloudinary({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return CloudinaryService.uploadImage(bytes: bytes, fileName: fileName);
  }
}

import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'cloudinary_service.dart';

class NoticeService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref("notice_board");

  Stream<DatabaseEvent> noticeStream() => _ref.onValue;

  Future<void> addNotice({
    required String title,
    required String description,
    required String category,
    required String department,
    required String imageUrl,
    required String postedByName,
    required String postedByRole,
  }) async {
    final newRef = _ref.push();

    await newRef.set({
      "title": title,
      "description": description,
      "category": category,
      "department": department,
      "imageUrl": imageUrl,
      "postedByName": postedByName,
      "postedByRole": postedByRole,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteNotice(String noticeId) async {
    await _ref.child(noticeId).remove();
  }

  Future<String> uploadImageToCloudinary({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return CloudinaryService.uploadImage(bytes: bytes, fileName: fileName);
  }
}

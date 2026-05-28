import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // ✅ From your screenshot
  static const String cloudName = "dhpcgb8ro";
  static const String uploadPreset = "campus_hub_unsigned";

  static Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uri =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest("POST", uri);

    request.fields["upload_preset"] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: fileName,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        "Cloudinary upload failed (${response.statusCode}): $responseBody",
      );
    }

    final data = jsonDecode(responseBody);

    if (data["secure_url"] == null) {
      throw Exception("Cloudinary response missing secure_url: $responseBody");
    }

    return data["secure_url"];
  }
}

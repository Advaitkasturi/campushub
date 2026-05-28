import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/notice_service.dart';

class PostNoticeScreen extends StatefulWidget {
  const PostNoticeScreen({super.key});

  @override
  State<PostNoticeScreen> createState() => _PostNoticeScreenState();
}

class _PostNoticeScreenState extends State<PostNoticeScreen> {
  final NoticeService _service = NoticeService();

  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final departmentCtrl = TextEditingController();

  String category = "Exams";
  String campus = "GNIT";
  bool loading = false;

  File? _selectedImageFile;

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    departmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (picked == null) return;

      setState(() {
        _selectedImageFile = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image pick failed: $e")),
      );
    }
  }

  Future<Uint8List> _compressToJpegBytes(String path) async {
    final result = await FlutterImageCompress.compressWithFile(
      path,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception("Image conversion failed (null bytes)");
    }

    return result;
  }

  // ✅ Fetch current user name + role from Firebase profile
  Future<Map<String, String>> _getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final data = await AuthService().getUserData(user.uid);

    final name = (data["name"] ?? "Unknown").toString();
    final role = (data["role"] ?? "student").toString();

    return {"name": name, "role": role};
  }

  Future<void> _postNotice() async {
    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final dept = departmentCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter title and description")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // ✅ Get name + role for showing in Home Feed
      final profile = await _getCurrentUserProfile();
      final postedByName = profile["name"] ?? "Unknown";
      final postedByRole = profile["role"] ?? "student";

      String imageUrl = "";

      // ✅ Upload image if selected
      if (_selectedImageFile != null) {
        final Uint8List bytes =
            await _compressToJpegBytes(_selectedImageFile!.path);

        imageUrl = await _service.uploadImageToCloudinary(
          bytes: bytes,
          fileName: "notice_${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
      }

      // ✅ Add notice with postedBy fields
      await _service.addNotice(
        title: title,
        description: desc,
        category: category,
        department: dept.isEmpty ? campus : "$campus • $dept",
        imageUrl: imageUrl,

        // ✅ IMPORTANT
        postedByName: postedByName,
        postedByRole: postedByRole,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to post notice: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          "Post Notice",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field(titleCtrl, "Title"),
            _field(descCtrl, "Description", max: 4),

            // ✅ Image upload
            _label("Photo (Optional)"),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _selectedImageFile == null
                          ? const Icon(Icons.image_outlined,
                              color: Colors.black54)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedImageFile == null
                            ? "Tap to select photo"
                            : "Photo selected ✔",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const Icon(Icons.upload_rounded, color: Colors.black54),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            _dropdown(
              "Category",
              category,
              ["Exams", "Holidays", "Placements", "Fee Deadlines"],
              (v) => setState(() => category = v),
            ),

            _dropdown(
              "Campus",
              campus,
              ["GNIT", "GNITC"],
              (v) => setState(() => campus = v),
            ),

            _field(
              departmentCtrl,
              "Department (Optional) e.g. CSE / ECE / IT",
              max: 1,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: loading ? null : _postNotice,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        "Post",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {int max = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: max,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.black38),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.subText,
          ),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}

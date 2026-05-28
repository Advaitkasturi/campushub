import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../services/lost_found_service.dart';

class PostLostFoundScreen extends StatefulWidget {
  const PostLostFoundScreen({super.key});

  @override
  State<PostLostFoundScreen> createState() => _PostLostFoundScreenState();
}

class _PostLostFoundScreenState extends State<PostLostFoundScreen> {
  final LostFoundService _service = LostFoundService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // ✅ compulsory phone number (saved only inside post)
  final TextEditingController phoneController = TextEditingController();

  String selectedType = "Lost";
  String selectedCategory = "Wallet";

  bool loading = false;

  File? _selectedImageFile;

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    locationController.dispose();
    phoneController.dispose();
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

  Future<Map<String, String>> _getPosterDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final uid = user.uid;

    final snap = await FirebaseDatabase.instance.ref("users/$uid").get();

    String name = user.displayName ?? "";
    String email = user.email ?? "";

    if (snap.exists && snap.value != null) {
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      name = (data["name"] ?? name).toString();
      email = (data["email"] ?? email).toString();
    }

    return {
      "uid": uid,
      "name": name.isEmpty ? "Unknown User" : name,
      "email": email.isEmpty ? "No Email" : email,
    };
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

  // ✅ Indian mobile validation (10 digits + starts with 6/7/8/9)
  bool _isValidIndianPhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 10) return false;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  String _cleanPhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> postItem() async {
    final title = titleController.text.trim();
    final desc = descController.text.trim();
    final location = locationController.text.trim();

    final phoneRaw = phoneController.text.trim();
    final phone = _cleanPhone(phoneRaw);

    if (title.isEmpty || desc.isEmpty || location.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (!_isValidIndianPhone(phoneRaw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid Indian 10-digit number")),
      );
      return;
    }

    if (selectedType == "Found" && _selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo is required for Found posts")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final poster = await _getPosterDetails();

      String imageUrl = "";

      if (_selectedImageFile != null) {
        final Uint8List bytes =
            await _compressToJpegBytes(_selectedImageFile!.path);

        imageUrl = await _service.uploadImageToCloudinary(
          bytes: bytes,
          fileName: "lost_found_${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
      }

      await _service.addPost(
        type: selectedType,
        title: title,
        desc: desc,
        category: selectedCategory,
        location: location,
        imageUrl: imageUrl,
        postedByUid: poster["uid"]!,
        postedByName: poster["name"]!,
        postedByEmail: poster["email"]!,
        postedByPhone: phone, // ✅ stored in post only
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Posted successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isFound = selectedType == "Found";

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          "Post Lost/Found",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Type"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "Lost", child: Text("Lost")),
                      DropdownMenuItem(value: "Found", child: Text("Found")),
                    ],
                    onChanged: (v) {
                      setState(() {
                        selectedType = v ?? "Lost";
                        if (selectedType == "Lost") _selectedImageFile = null;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _label(isFound ? "Photo (Required for Found)" : "Photo (Optional)"),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFound && _selectedImageFile == null
                          ? Colors.redAccent
                          : AppColors.border,
                    ),
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

              _label("Title"),
              _textBox(controller: titleController, hint: "Wallet / Phone / ID Card"),

              const SizedBox(height: 12),

              _label("Category"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "Wallet", child: Text("Wallet")),
                      DropdownMenuItem(value: "Phone", child: Text("Phone")),
                      DropdownMenuItem(value: "ID Card", child: Text("ID Card")),
                      DropdownMenuItem(value: "Keys", child: Text("Keys")),
                      DropdownMenuItem(value: "Other", child: Text("Other")),
                    ],
                    onChanged: (v) =>
                        setState(() => selectedCategory = v ?? "Wallet"),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _label("Location"),
              _textBox(controller: locationController, hint: "Library / Canteen / Parking"),

              const SizedBox(height: 12),

              _label("Contact Number (Required)"),
              _textBox(
                controller: phoneController,
                hint: "10-digit Indian number",
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),

              const SizedBox(height: 12),

              _label("Description"),
              _textBox(
                controller: descController,
                hint: "Write details...",
                maxLines: 4,
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: loading ? null : postItem,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
    );
  }

  Widget _textBox({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.black38),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

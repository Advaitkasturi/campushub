import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';

class PostStoryScreen extends StatefulWidget {
  const PostStoryScreen({super.key});

  @override
  State<PostStoryScreen> createState() => _PostStoryScreenState();
}

class _PostStoryScreenState extends State<PostStoryScreen> {
  final ImagePicker _picker = ImagePicker();

  final DatabaseReference _storiesRef = FirebaseDatabase.instance.ref("stories");
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("users");
  final FirebaseAuth _auth = FirebaseAuth.instance;

  File? _selectedImageFile;
  bool loading = false;

  // text overlay
  final TextEditingController _textCtrl = TextEditingController();
  bool _showTextEditor = false;

  String storyText = "";
  Offset textOffset = const Offset(40, 120);
  Color textColor = Colors.white;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      if (picked == null) return;

      setState(() {
        _selectedImageFile = File(picked.path);
        _showTextEditor = false;
        storyText = "";
        textOffset = const Offset(40, 120);
        textColor = Colors.white;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera failed: $e")),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;

      setState(() {
        _selectedImageFile = File(picked.path);
        _showTextEditor = false;
        storyText = "";
        textOffset = const Offset(40, 120);
        textColor = Colors.white;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gallery pick failed: $e")),
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

  Future<Map<String, dynamic>> _getMyProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    final snap = await _usersRef.child(uid).get();
    final data = snap.value;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> _postStory() async {
    if (_selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select an image first")),
      );
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final Uint8List bytes =
          await _compressToJpegBytes(_selectedImageFile!.path);

      // ✅ Upload to Cloudinary (CORRECT METHOD NAME)
      final imageUrl = await CloudinaryService.uploadImage(
        bytes: bytes,
        fileName: "story_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      // ✅ Get user profile (name/role)
      final profile = await _getMyProfile();
      final postedByName = (profile["name"] ?? "User").toString();
      final postedByRole = (profile["role"] ?? "student").toString();

      // ✅ Save to Firebase
      final newRef = _storiesRef.push();
      await newRef.set({
        "id": newRef.key,
        "title": storyText.trim(),
        "imageUrl": imageUrl,
        "postedBy": uid,
        "postedByName": postedByName,
        "postedByRole": postedByRole,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
        "expiresAt":
            DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Story posted ✅")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to post story: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openTextEditor() {
    setState(() {
      _showTextEditor = true;
      _textCtrl.text = storyText;
    });
  }

  void _applyText() {
    setState(() {
      storyText = _textCtrl.text;
      _showTextEditor = false;
    });
  }

  void _changeTextColor() {
    const colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
    ];

    final currentIndex = colors.indexOf(textColor);
    final nextIndex = (currentIndex + 1) % colors.length;

    setState(() {
      textColor = colors[nextIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _selectedImageFile == null
          ? _emptyPickUI()
          : Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    _selectedImageFile!,
                    fit: BoxFit.cover,
                  ),
                ),

                // top bar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _circleBtn(
                        icon: Icons.close,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      _circleBtn(
                        icon: Icons.text_fields,
                        onTap: _openTextEditor,
                      ),
                      const SizedBox(width: 10),
                      _circleBtn(
                        icon: Icons.color_lens_outlined,
                        onTap: _changeTextColor,
                      ),
                    ],
                  ),
                ),

                // draggable text overlay
                if (storyText.trim().isNotEmpty)
                  Positioned(
                    left: textOffset.dx,
                    top: textOffset.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          textOffset = Offset(
                            textOffset.dx + details.delta.dx,
                            textOffset.dy + details.delta.dy,
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          storyText,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),

                // bottom bar
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: _pillBtn(
                          label: "Camera",
                          icon: Icons.camera_alt_outlined,
                          onTap: _pickFromCamera,
                          bg: Colors.white.withOpacity(0.18),
                          textColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pillBtn(
                          label: "Gallery",
                          icon: Icons.photo_library_outlined,
                          onTap: _pickFromGallery,
                          bg: Colors.white.withOpacity(0.18),
                          textColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pillBtn(
                          label: loading ? "Posting..." : "Share",
                          icon: Icons.send_rounded,
                          onTap: loading ? null : _postStory,
                          bg: Colors.white,
                          textColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // text editor overlay
                if (_showTextEditor)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.55),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                children: [
                                  _circleBtn(
                                    icon: Icons.close,
                                    onTap: () => setState(() {
                                      _showTextEditor = false;
                                    }),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "Add Text",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  _circleBtn(
                                    icon: Icons.check,
                                    onTap: _applyText,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(
                                controller: _textCtrl,
                                autofocus: true,
                                maxLines: 3,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Type something...",
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.white54,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (loading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _emptyPickUI() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _circleBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Text(
                  "Create Story",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_a_photo_outlined,
                        size: 42,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Add a photo to your story",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Capture now or choose from gallery",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _pillBtn(
                              label: "Camera",
                              icon: Icons.camera_alt_outlined,
                              onTap: _pickFromCamera,
                              bg: Colors.white,
                              textColor: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _pillBtn(
                              label: "Gallery",
                              icon: Icons.photo_library_outlined,
                              onTap: _pickFromGallery,
                              bg: Colors.white.withOpacity(0.18),
                              textColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              "Check twice before uploading !",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white54,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _pillBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required Color bg,
    required Color textColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

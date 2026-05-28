import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/lost_found_service.dart';

class PostEventScreen extends StatefulWidget {
  const PostEventScreen({super.key});

  @override
  State<PostEventScreen> createState() => _PostEventScreenState();
}

class _PostEventScreenState extends State<PostEventScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController venueController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController linkController = TextEditingController();

  final EventService _eventService = EventService();
  final LostFoundService _uploadService = LostFoundService();

  String selectedCategory = "Tech";

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  bool posting = false;

  Uint8List? _bannerBytes;
  String _bannerName = "";

  Future<void> pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> pickBanner() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _bannerBytes = bytes;
        _bannerName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Banner pick failed: $e")),
      );
    }
  }

  String get formattedDate {
    if (selectedDate == null) return "Select date";
    return "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}";
  }

  String get formattedTime {
    if (selectedTime == null) return "Select time";
    final hour = selectedTime!.hourOfPeriod.toString().padLeft(2, "0");
    final minute = selectedTime!.minute.toString().padLeft(2, "0");
    final ampm = selectedTime!.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minute $ampm";
  }

  String get firebaseDate {
    if (selectedDate == null) return "";
    final y = selectedDate!.year.toString().padLeft(4, "0");
    final m = selectedDate!.month.toString().padLeft(2, "0");
    final d = selectedDate!.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  bool isValidUrl(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith("http://") || trimmed.startsWith("https://");
  }

  Future<Map<String, dynamic>> _getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final data = await AuthService().getUserData(user.uid);

    return {
      "name": (data["name"] ?? "Unknown").toString(),
      "role": (data["role"] ?? "student").toString(),
    };
  }

  Future<void> postEvent() async {
    final title = titleController.text.trim();
    final venue = venueController.text.trim();
    final desc = descController.text.trim();
    final regLink = linkController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter event title")),
      );
      return;
    }

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select event date")),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select event time")),
      );
      return;
    }

    if (venue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter venue")),
      );
      return;
    }

    if (regLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter registration link")),
      );
      return;
    }

    if (!isValidUrl(regLink)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Link must start with https:// or http://"),
        ),
      );
      return;
    }

    setState(() => posting = true);

    try {
      // ✅ fetch name + role from profile
      final profile = await _getCurrentUserProfile();
      final postedByName = profile["name"].toString();
      final postedByRole = profile["role"].toString();

      String bannerUrl = "";

      if (_bannerBytes != null) {
        bannerUrl = await _uploadService.uploadImageToCloudinary(
          bytes: _bannerBytes!,
          fileName: "event_banner_${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
      }

      await _eventService.addEvent(
        title: title,
        category: selectedCategory,
        date: firebaseDate,
        time: formattedTime,
        location: venue,
        description: desc,
        registrationLink: regLink,
        bannerUrl: bannerUrl,

        // ✅ IMPORTANT
        postedByName: postedByName,
        postedByRole: postedByRole,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Event posted successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to post event: $e")),
      );
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    venueController.dispose();
    seatsController.dispose();
    descController.dispose();
    linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          "Add Event",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Create a new campus event",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subText,
                ),
              ),
              const SizedBox(height: 16),

              _Label("Event Banner (Optional)"),
              GestureDetector(
                onTap: pickBanner,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _bannerBytes == null
                            ? Container(
                                height: 160,
                                width: double.infinity,
                                color: const Color(0xFFF1F5F9),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_outlined,
                                        size: 32, color: Colors.black54),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Tap to upload banner",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.memory(
                                _bannerBytes!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.upload_rounded,
                              size: 18, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _bannerBytes == null
                                  ? "No banner selected"
                                  : "Selected: ${_bannerName.isEmpty ? "banner.jpg" : _bannerName}",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              _Label("Event Title"),
              _TextBox(controller: titleController, hint: "AI Workshop"),
              const SizedBox(height: 12),

              _Label("Category"),
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
                      DropdownMenuItem(value: "Tech", child: Text("Tech")),
                      DropdownMenuItem(
                          value: "Cultural", child: Text("Cultural")),
                      DropdownMenuItem(value: "Sports", child: Text("Sports")),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedCategory = value);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _Label("Date"),
              _PickerTile(
                text: formattedDate,
                icon: Icons.calendar_month_outlined,
                onTap: pickDate,
              ),

              const SizedBox(height: 12),

              _Label("Time"),
              _PickerTile(
                text: formattedTime,
                icon: Icons.schedule_rounded,
                onTap: pickTime,
              ),

              const SizedBox(height: 12),

              _Label("Venue"),
              _TextBox(controller: venueController, hint: "Seminar Hall"),

              const SizedBox(height: 12),

              _Label("Seats (optional)"),
              _TextBox(
                controller: seatsController,
                hint: "100",
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              _Label("Description"),
              _TextBox(
                controller: descController,
                hint: "Write event details...",
                maxLines: 4,
              ),

              const SizedBox(height: 12),

              _Label("Registration Link (Required)"),
              _TextBox(
                controller: linkController,
                hint: "https://forms.gle/xxxxxx",
                keyboardType: TextInputType.url,
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
                  onPressed: posting ? null : postEvent,
                  child: posting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          "Post Event",
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
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _TextBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _TextBox({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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

class _PickerTile extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerTile({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color:
                      text.contains("Select") ? Colors.black38 : AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

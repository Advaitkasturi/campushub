import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../services/lost_found_service.dart';
import 'post_lost_found_screen.dart';

class LostFoundScreen extends StatefulWidget {
  final String userRole; // "admin" or "student"
  const LostFoundScreen({super.key, required this.userRole});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  int selectedTab = 0; // 0 = Lost, 1 = Found
  final LostFoundService _service = LostFoundService();

  static const int expiryMs = 48 * 60 * 60 * 1000;

  bool _isExpired(dynamic createdAt) {
    if (createdAt == null) return false;
    final int created =
        (createdAt is int) ? createdAt : int.tryParse(createdAt.toString()) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - created) > expiryMs;
  }

  // ✅ keyword matching (simple AI)
  List<Map<String, dynamic>> _findMatches(
    Map<String, dynamic> current,
    List<Map<String, dynamic>> all,
  ) {
    final String type = (current["type"] ?? "").toString();
    final String title = (current["title"] ?? "").toString().toLowerCase();
    final String desc = (current["desc"] ?? "").toString().toLowerCase();
    final String category = (current["category"] ?? "").toString().toLowerCase();
    final String location = (current["location"] ?? "").toString().toLowerCase();

    final String opposite = type == "Found" ? "Lost" : "Found";

    final keywords = <String>{
      ...title.split(" "),
      ...desc.split(" "),
      category,
      location,
    }.where((w) => w.trim().length > 2).toSet();

    final matches = all.where((p) {
      if ((p["type"] ?? "").toString() != opposite) return false;

      final t = (p["title"] ?? "").toString().toLowerCase();
      final d = (p["desc"] ?? "").toString().toLowerCase();
      final c = (p["category"] ?? "").toString().toLowerCase();
      final l = (p["location"] ?? "").toString().toLowerCase();

      int score = 0;
      for (final k in keywords) {
        if (t.contains(k)) score++;
        if (d.contains(k)) score++;
        if (c.contains(k)) score += 2;
        if (l.contains(k)) score += 2;
      }

      return score >= 3;
    }).toList();

    return matches.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.userRole == "admin";

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostLostFoundScreen()),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lost & Found",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Lost on campus? We’ve got you.",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Tabs
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        title: "Lost",
                        active: selectedTab == 0,
                        onTap: () => setState(() => selectedTab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        title: "Found",
                        active: selectedTab == 1,
                        onTap: () => setState(() => selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _service.lostFoundStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return Center(
                        child: Text(
                          "No posts available",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subText,
                          ),
                        ),
                      );
                    }

                    final raw = snapshot.data!.snapshot.value;

                    if (raw is! Map) {
                      return Center(
                        child: Text(
                          "Invalid data format",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subText,
                          ),
                        ),
                      );
                    }

                    final allPosts = raw.entries.map((e) {
                      final map = Map<String, dynamic>.from(e.value);
                      map["id"] = e.key;
                      return map;
                    }).toList();

                    final visiblePosts =
                        allPosts.where((p) => !_isExpired(p["createdAt"])).toList();

                    final tabType = selectedTab == 0 ? "Lost" : "Found";

                    final filtered = visiblePosts
                        .where((p) => (p["type"] ?? "").toString() == tabType)
                        .toList();

                    filtered.sort((a, b) {
                      final aTime = (a["createdAt"] is int)
                          ? a["createdAt"] as int
                          : int.tryParse(a["createdAt"].toString()) ?? 0;

                      final bTime = (b["createdAt"] is int)
                          ? b["createdAt"] as int
                          : int.tryParse(b["createdAt"].toString()) ?? 0;

                      return bTime.compareTo(aTime);
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          "No $tabType posts available",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subText,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final matches = _findMatches(item, visiblePosts);

                        return _LostFoundCard(
                          title: (item["title"] ?? "").toString(),
                          desc: (item["desc"] ?? "").toString(),
                          location: (item["location"] ?? "").toString(),
                          category: (item["category"] ?? "").toString(),
                          type: (item["type"] ?? "").toString(),
                          imageUrl: (item["imageUrl"] ?? "").toString(),
                          postedByName: (item["postedByName"] ?? "Unknown").toString(),
                          postedByEmail:
                              (item["postedByEmail"] ?? "Not available").toString(),

                          // ✅ NEW
                          postedByPhone: (item["postedByPhone"] ?? "").toString(),

                          isAdmin: isAdmin,
                          matches: matches,
                          onDelete: () async {
                            final postId = item["id"].toString();
                            try {
                              await _service.deletePost(postId);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Post deleted")),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Delete failed: $e")),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _LostFoundCard extends StatelessWidget {
  final String title;
  final String desc;
  final String location;
  final String category;
  final String type;
  final String imageUrl;

  final String postedByName;
  final String postedByEmail;

  // ✅ NEW
  final String postedByPhone;

  final bool isAdmin;
  final VoidCallback onDelete;
  final List<Map<String, dynamic>> matches;

  const _LostFoundCard({
    required this.title,
    required this.desc,
    required this.location,
    required this.category,
    required this.type,
    required this.imageUrl,
    required this.postedByName,
    required this.postedByEmail,
    required this.postedByPhone,
    required this.isAdmin,
    required this.onDelete,
    required this.matches,
  });

  void _openImagePreview(BuildContext context) {
    if (imageUrl.trim().isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _contactUser(BuildContext context) async {
    final phone = postedByPhone.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available")),
      );
      return;
    }

    final uri = Uri.parse("tel:$phone");

    final ok = await launchUrl(uri);

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open dialer")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLost = type.toLowerCase() == "lost";
    final bool hasImage = imageUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            GestureDetector(
              onTap: () => _openImagePreview(context),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (isAdmin)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLost ? const Color(0xFFFFE4E6) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLost ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Posted by section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Posted by: $postedByName",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        postedByEmail,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.subText,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(icon: Icons.category_outlined, text: category),
              _MiniChip(icon: Icons.location_on_outlined, text: location),
            ],
          ),

          // Possible Matches
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              "Possible Match 🔥",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: matches.map((m) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${m["type"]}: ${m["title"]}",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),

          // ✅ UPDATED BUTTON
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _contactUser(context),
              child: Text(
                "Contact",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

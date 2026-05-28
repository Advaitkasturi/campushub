import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/app_colors.dart';
import '../../services/notice_service.dart';
import 'post_notice_screen.dart';

class NoticeBoardScreen extends StatefulWidget {
  final String userRole; // admin / student
  const NoticeBoardScreen({super.key, required this.userRole});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  final NoticeService _service = NoticeService();

  String selectedFilter = "All";

  final List<String> filters = [
    "All",
    "GNIT",
    "GNITC",
    "Exams",
    "Holidays",
    "Placements",
    "Fee Deadlines",
  ];

  int _safeTime(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  bool _matchesFilter(Map<String, dynamic> n) {
    final String cat = (n["category"] ?? "").toString();
    final String dept = (n["department"] ?? "").toString();

    if (selectedFilter == "All") return true;

    // filter by category
    if (cat == selectedFilter) return true;

    // filter by campus (GNIT / GNITC)
    if (dept.startsWith(selectedFilter)) return true;

    return false;
  }

  String _buildTag(Map<String, dynamic> n) {
    final String cat = (n["category"] ?? "").toString();
    final String dept = (n["department"] ?? "").toString();

    if (dept.isEmpty) return cat;
    if (cat.isEmpty) return dept;
    return "$cat • $dept";
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case "Exams":
        return Icons.edit_note_rounded;
      case "Holidays":
        return Icons.beach_access_rounded;
      case "Placements":
        return Icons.work_outline_rounded;
      case "Fee Deadlines":
        return Icons.payments_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.userRole == "admin";

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostNoticeScreen()),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "📢 Notice Board",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Official college updates & announcements",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.subText,
                ),
              ),
              const SizedBox(height: 16),

              // ✅ Filter Chips
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final f = filters[index];
                    final active = selectedFilter == f;

                    return GestureDetector(
                      onTap: () => setState(() => selectedFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            f,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : AppColors.text,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _service.noticeStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return _empty();
                    }

                    final raw = snapshot.data!.snapshot.value;
                    if (raw is! Map) return _empty();

                    final data = Map<dynamic, dynamic>.from(raw);

                    final notices = <Map<String, dynamic>>[];

                    for (final entry in data.entries) {
                      if (entry.value is! Map) continue;

                      final map = Map<String, dynamic>.from(
                          entry.value as Map<dynamic, dynamic>);
                      map["id"] = entry.key.toString();
                      notices.add(map);
                    }

                    final filtered = notices.where(_matchesFilter).toList();

                    filtered.sort((a, b) {
                      final aTime = _safeTime(a["createdAt"]);
                      final bTime = _safeTime(b["createdAt"]);
                      return bTime.compareTo(aTime);
                    });

                    if (filtered.isEmpty) return _empty();

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final n = filtered[i];

                        return _NoticeCard(
                          title: (n["title"] ?? "").toString(),
                          desc: (n["description"] ?? "").toString(),
                          tag: _buildTag(n),
                          icon: _iconForCategory((n["category"] ?? "").toString()),
                          imageUrl: (n["imageUrl"] ?? "").toString(), // ✅ NEW
                          isAdmin: isAdmin,
                          onDelete: () async {
                            try {
                              await _service.deleteNotice(n["id"].toString());
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Notice deleted")),
                              );
                            } catch (e) {
                              if (!mounted) return;
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

  Widget _empty() {
    return Center(
      child: Text(
        "No notices available",
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.subText,
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String desc;
  final String tag;
  final IconData icon;
  final String imageUrl; // ✅ NEW
  final bool isAdmin;
  final VoidCallback onDelete;

  const _NoticeCard({
    required this.title,
    required this.desc,
    required this.tag,
    required this.icon,
    required this.imageUrl,
    required this.isAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Show Image if available
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.contain, // ✅ shows full image (no crop)
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  alignment: Alignment.center,
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(Icons.broken_image_outlined),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    color: const Color(0xFFF1F5F9),
                    child: const CircularProgressIndicator(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: Colors.black87),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  title.isEmpty ? "Untitled Notice" : title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),

              if (isAdmin)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            desc.isEmpty ? "No description" : desc,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.subText,
            ),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

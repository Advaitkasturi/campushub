import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../events/events_list_screen.dart';
import '../profile/profile_screen.dart';
import '../notices/notice_board_screen.dart';
import '../stories/post_story_screen.dart';
import '../stories/story_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userRole; // "admin" or "student"

  const HomeScreen({super.key, required this.userRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _eventsRef = FirebaseDatabase.instance.ref("events");
  final DatabaseReference _noticeRef =
      FirebaseDatabase.instance.ref("notice_board");
  final DatabaseReference _storiesRef = FirebaseDatabase.instance.ref("stories");

  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _safeTime(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  bool _isPastEvent(String dateString) {
    try {
      final eventDate = DateTime.parse(dateString);
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      return eventDate.isBefore(todayOnly);
    } catch (_) {
      return false;
    }
  }

  String _timeAgo(int ms) {
    if (ms == 0) return "Just now";
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - ms;

    final minutes = (diff / (60 * 1000)).floor();
    final hours = (diff / (60 * 60 * 1000)).floor();
    final days = (diff / (24 * 60 * 60 * 1000)).floor();

    if (minutes < 1) return "Just now";
    if (minutes < 60) return "${minutes}m ago";
    if (hours < 24) return "${hours}h ago";
    return "${days}d ago";
  }

  Future<void> _openLink(String link) async {
    final trimmed = link.trim();

    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration link not available")),
      );
      return;
    }

    final uri = Uri.tryParse(trimmed);

    if (uri == null || (!uri.isScheme("https") && !uri.isScheme("http"))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid registration link")),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open link")),
      );
    }
  }

  void _openNoticeBoard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoticeBoardScreen(userRole: widget.userRole),
      ),
    );
  }

  void _openEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventsListScreen(userRole: widget.userRole),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  List<Map<String, dynamic>> _normalizeListFromSnapshot(dynamic raw) {
    if (raw == null) return [];
    if (raw is! Map) return [];

    final map = Map<dynamic, dynamic>.from(raw);
    final list = <Map<String, dynamic>>[];

    for (final entry in map.entries) {
      if (entry.value is! Map) continue;
      final item = Map<String, dynamic>.from(entry.value as Map);
      item["id"] = entry.key.toString();
      list.add(item);
    }

    return list;
  }

  // ✅ expiry check (24 hrs)
  bool _isExpiredStory(Map<String, dynamic> s) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // if expiresAt exists use it
    final expiresAt = _safeTime(s["expiresAt"]);
    if (expiresAt > 0) return now >= expiresAt;

    // fallback createdAt + 24h
    final createdAt = _safeTime(s["createdAt"]);
    if (createdAt == 0) return false;

    return (now - createdAt) > 24 * 60 * 60 * 1000;
  }

  List<Map<String, dynamic>> _filterExpiredStories(List<Map<String, dynamic>> list) {
    return list.where((s) => !_isExpiredStory(s)).toList();
  }

  List<Map<String, dynamic>> _buildFeed({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> notices,
  }) {
    final feed = <Map<String, dynamic>>[];

    for (final e in events) {
      feed.add({
        "type": "event",
        "createdAt": _safeTime(e["createdAt"]),
        "data": e,
      });
    }

    for (final n in notices) {
      feed.add({
        "type": "notice",
        "createdAt": _safeTime(n["createdAt"]),
        "data": n,
      });
    }

    feed.sort((a, b) =>
        _safeTime(b["createdAt"]).compareTo(_safeTime(a["createdAt"])));
    return feed;
  }

  String _displayNameFromPost(Map<String, dynamic> data) {
    final name = (data["postedByName"] ?? "").toString().trim();
    if (name.isNotEmpty) return name;

    final role = (data["postedByRole"] ?? "").toString();
    if (role == "admin") return "Admin";
    return "Unknown";
  }

  bool _isVerifiedFromPost(Map<String, dynamic> data) {
    final role = (data["postedByRole"] ?? "").toString();
    return role == "admin";
  }

  // ✅ mark story as seen in firebase
  Future<void> _markStorySeen(String storyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _storiesRef.child(storyId).child("seenBy").child(uid).set(true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.userRole == "admin";
    final uid = _auth.currentUser?.uid;

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    "CampusHub",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _openNoticeBoard,
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: AppColors.text,
                  ),
                  IconButton(
                    onPressed: _openProfile,
                    icon: const Icon(Icons.person_outline_rounded),
                    color: AppColors.text,
                  ),
                ],
              ),
            ),

            // ✅ Stories row
            SizedBox(
              height: 112,
              child: StreamBuilder<DatabaseEvent>(
                stream: _storiesRef.onValue,
                builder: (context, snapshot) {
                  final raw = snapshot.data?.snapshot.value;
                  var stories = _normalizeListFromSnapshot(raw);

                  // ✅ remove expired from UI
                  stories = _filterExpiredStories(stories);

                  stories.sort((a, b) => _safeTime(b["createdAt"])
                      .compareTo(_safeTime(a["createdAt"])));

                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (isAdmin)
                        _AddStoryCircle(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PostStoryScreen(),
                              ),
                            );
                          },
                        ),

                      ...stories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final s = entry.value;

                        final storyId = (s["id"] ?? "").toString();

                        final name = (s["postedByName"] ?? "Unknown").toString();
                        final role = (s["postedByRole"] ?? "").toString();
                        final isVerified = role == "admin";
                        final imageUrl = (s["imageUrl"] ?? "").toString();

                        final seenBy = s["seenBy"];
                        bool isSeen = false;

                        if (uid != null && seenBy is Map) {
                          isSeen = seenBy.containsKey(uid);
                        }

                        return _StoryCircle(
                          name: name,
                          isVerified: isVerified,
                          imageUrl: imageUrl,
                          isSeen: isSeen, // ✅ NEW
                          onTap: () async {
                            // mark seen first
                            if (storyId.isNotEmpty) {
                              await _markStorySeen(storyId);
                            }

                            // open viewer
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewerScreen(
                                  stories: stories,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // ✅ Feed
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _eventsRef.onValue,
                builder: (context, eventsSnap) {
                  return StreamBuilder<DatabaseEvent>(
                    stream: _noticeRef.onValue,
                    builder: (context, noticeSnap) {
                      final eventsRaw = eventsSnap.data?.snapshot.value;
                      final noticesRaw = noticeSnap.data?.snapshot.value;

                      final events =
                          _normalizeListFromSnapshot(eventsRaw).where((e) {
                        final date = (e["date"] ?? "").toString();
                        return !_isPastEvent(date);
                      }).toList();

                      final notices = _normalizeListFromSnapshot(noticesRaw);

                      final feed = _buildFeed(events: events, notices: notices);

                      if (feed.isEmpty) {
                        return Center(
                          child: Text(
                            "No updates yet 👀",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.subText,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                        itemCount: feed.length,
                        itemBuilder: (context, index) {
                          final item = feed[index];
                          final type = (item["type"] ?? "").toString();
                          final createdAt = _safeTime(item["createdAt"]);
                          final data =
                              Map<String, dynamic>.from(item["data"] as Map);

                          final postedByName = _displayNameFromPost(data);
                          final isVerified = _isVerifiedFromPost(data);

                          if (type == "event") {
                            final bannerUrl = (data["bannerUrl"] ?? "").toString();
                            final regLink =
                                (data["registrationLink"] ?? "").toString();

                            return _EventPostCard(
                              title: (data["title"] ?? "").toString(),
                              category: (data["category"] ?? "").toString(),
                              date: (data["date"] ?? "").toString(),
                              time: (data["time"] ?? "").toString(),
                              location: (data["location"] ?? "").toString(),
                              imageUrl: bannerUrl,
                              postedByName: postedByName,
                              isVerified: isVerified,
                              timeAgo: _timeAgo(createdAt),
                              onRegister: () => _openLink(regLink),
                              onViewAll: _openEvents,
                            );
                          }

                          return _NoticePostCard(
                            title: (data["title"] ?? "").toString(),
                            description: (data["description"] ?? "").toString(),
                            category: (data["category"] ?? "").toString(),
                            campusDept: (data["department"] ?? "").toString(),
                            imageUrl: (data["imageUrl"] ?? "").toString(),
                            postedByName: postedByName,
                            isVerified: isVerified,
                            timeAgo: _timeAgo(createdAt),
                            onReadMore: _openNoticeBoard,
                          );
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
    );
  }
}

// ===================== STORIES UI =======================

class _AddStoryCircle extends StatelessWidget {
  final VoidCallback onTap;
  const _AddStoryCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 68,
              width: 68,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              "Your story",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  final String name;
  final bool isVerified;
  final String imageUrl;
  final bool isSeen; // ✅ NEW
  final VoidCallback onTap;

  const _StoryCircle({
    required this.name,
    required this.isVerified,
    required this.imageUrl,
    required this.isSeen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ ring color logic
    final Color ringColor = isSeen ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 68,
              width: 68,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringColor, // ✅ BLACK/WHITE ring
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.image, color: Colors.black54)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 74,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isVerified)
                    const Icon(
                      Icons.verified,
                      size: 14,
                      color: Color(0xFF1D9BF0),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== FEED UI ==========================

class _PostHeader extends StatelessWidget {
  final String name;
  final bool verified;
  final String timeAgo;
  final String subtitle;

  const _PostHeader({
    required this.name,
    required this.verified,
    required this.timeAgo,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFF1F5F9),
            child: Icon(Icons.person, color: Colors.black54),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (verified)
                      const Icon(Icons.verified,
                          size: 16, color: Color(0xFF1D9BF0)),
                    const SizedBox(width: 8),
                    Text(
                      "• $timeAgo",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert, color: Colors.black54),
        ],
      ),
    );
  }
}

class _EventPostCard extends StatelessWidget {
  final String title;
  final String category;
  final String date;
  final String time;
  final String location;
  final String imageUrl;

  final String postedByName;
  final bool isVerified;
  final String timeAgo;

  final VoidCallback onRegister;
  final VoidCallback onViewAll;

  const _EventPostCard({
    required this.title,
    required this.category,
    required this.date,
    required this.time,
    required this.location,
    required this.imageUrl,
    required this.postedByName,
    required this.isVerified,
    required this.timeAgo,
    required this.onRegister,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(
            name: postedByName,
            verified: isVerified,
            timeAgo: timeAgo,
            subtitle: category.isEmpty ? "Event" : category,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: imageUrl.isEmpty
                      ? Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.image,
                              size: 40, color: Colors.black54),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.broken_image,
                                size: 40, color: Colors.black54),
                          ),
                        ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          "$date • $time",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Text(
              title.isEmpty ? "Untitled Event" : title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location.isEmpty ? "Venue not set" : location,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: onRegister,
                    child: Text(
                      "Register",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: onViewAll,
                  child: Text(
                    "View All",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticePostCard extends StatelessWidget {
  final String title;
  final String description;
  final String category;
  final String campusDept;
  final String imageUrl;

  final String postedByName;
  final bool isVerified;
  final String timeAgo;

  final VoidCallback onReadMore;

  const _NoticePostCard({
    required this.title,
    required this.description,
    required this.category,
    required this.campusDept,
    required this.imageUrl,
    required this.postedByName,
    required this.isVerified,
    required this.timeAgo,
    required this.onReadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(
            name: postedByName,
            verified: isVerified,
            timeAgo: timeAgo,
            subtitle: category.isEmpty ? "Notice" : "$category • $campusDept",
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 90,
                    width: 90,
                    child: imageUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.image,
                                color: Colors.black54),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.broken_image,
                                  color: Colors.black54),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? "Untitled Notice" : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description.isEmpty ? "No description" : description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onReadMore,
                          child: Text(
                            "Read more",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

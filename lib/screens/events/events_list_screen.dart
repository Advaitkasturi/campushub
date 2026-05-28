import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../services/event_service.dart';
import 'post_event_screen.dart';

class EventsListScreen extends StatefulWidget {
  final String userRole; // "admin" or "student"
  const EventsListScreen({super.key, required this.userRole});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  int selectedCategory = 0;
  final List<String> categories = ["All", "Tech", "Cultural", "Sports"];

  final EventService _eventService = EventService();

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

  Future<void> _openRegistrationLink(String link) async {
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
        const SnackBar(content: Text("Could not open registration link")),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // ✅ Auto delete old events from database (admin only will succeed by rules)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _eventService.deletePastEvents();
      } catch (_) {
        // ignore (students can't delete due to rules)
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.userRole == "admin";

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        floatingActionButton: isAdmin
            ? FloatingActionButton(
                backgroundColor: AppColors.primary,
                elevation: 2,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PostEventScreen()),
                  );
                },
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Top Bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Events",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Discover campus events & register",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none_rounded),
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Categories Chips
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final bool active = selectedCategory == index;

                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          categories[index],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.text,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 🔥 Firebase Events List
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _eventService.eventsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return Center(
                        child: Text(
                          "No events available",
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
                          "Invalid events format",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subText,
                          ),
                        ),
                      );
                    }

                    final data = Map<dynamic, dynamic>.from(raw);

                    // Convert map to list with eventId included
                    final allEvents = data.entries.map((e) {
                      final map = Map<String, dynamic>.from(e.value);
                      map["id"] = e.key;
                      return map;
                    }).toList();

                    // Remove past events from UI
                    final upcomingEvents = allEvents.where((e) {
                      final date = (e["date"] ?? "").toString();
                      return !_isPastEvent(date);
                    }).toList();

                    // Filter by category
                    final filteredEvents = selectedCategory == 0
                        ? upcomingEvents
                        : upcomingEvents
                            .where((e) =>
                                (e["category"] ?? "").toString() ==
                                categories[selectedCategory])
                            .toList();

                    // Sort by date
                    filteredEvents.sort((a, b) {
                      final da =
                          DateTime.tryParse((a["date"] ?? "").toString()) ??
                              DateTime(2100);
                      final db =
                          DateTime.tryParse((b["date"] ?? "").toString()) ??
                              DateTime(2100);
                      return da.compareTo(db);
                    });

                    if (filteredEvents.isEmpty) {
                      return Center(
                        child: Text(
                          "No events in this category",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subText,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, i) {
                        final e = filteredEvents[i];

                        final String link =
                            (e["registrationLink"] ?? "").toString();

                        final String bannerUrl =
                            (e["bannerUrl"] ?? "").toString();

                        return _EventCardPremium(
                          title: (e["title"] ?? "").toString(),
                          category: (e["category"] ?? "").toString(),
                          date: (e["date"] ?? "").toString(),
                          time: (e["time"] ?? "").toString(),
                          venue: (e["location"] ?? "").toString(),
                          bannerUrl: bannerUrl,
                          isAdmin: isAdmin,
                          onRegister: () => _openRegistrationLink(link),
                          onDelete: () async {
                            final eventId = e["id"].toString();
                            await _eventService.deleteEvent(eventId);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Event deleted")),
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
      ),
    );
  }
}

class _EventCardPremium extends StatelessWidget {
  final String title;
  final String category;
  final String date;
  final String time;
  final String venue;

  final String bannerUrl;

  final bool isAdmin;
  final VoidCallback onRegister;
  final VoidCallback onDelete;

  const _EventCardPremium({
    required this.title,
    required this.category,
    required this.date,
    required this.time,
    required this.venue,
    required this.bannerUrl,
    required this.isAdmin,
    required this.onRegister,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasBanner = bannerUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Banner (full width)
          if (hasBanner) ...[
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 8,
                child: Image.network(
                  bannerUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: double.infinity,
                    color: const Color(0xFFF1F5F9),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(icon: Icons.category_outlined, text: category),
                    _Chip(
                      icon: Icons.calendar_month_outlined,
                      text: "$date • $time",
                    ),
                    _Chip(icon: Icons.location_on_outlined, text: venue),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({required this.icon, required this.text});

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

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;

  final DatabaseReference _storiesRef = FirebaseDatabase.instance.ref("stories");
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("users");
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int currentIndex = 0;
  late List<Map<String, dynamic>> _stories;

  Map<String, dynamic> _myProfile = {};
  bool _profileLoaded = false;

  Timer? _expiryTimer;
  Timer? _timeRefreshTimer;

  int _safeTime(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _timeAgo(int ms) {
    if (ms == 0) return "now";
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - ms;

    final minutes = (diff / (60 * 1000)).floor();
    final hours = (diff / (60 * 60 * 1000)).floor();
    final days = (diff / (24 * 60 * 60 * 1000)).floor();

    if (minutes < 1) return "now";
    if (minutes < 60) return "${minutes}m";
    if (hours < 24) return "${hours}h";
    return "${days}d";
  }

  bool _isExpired(Map<String, dynamic> s) {
    final expiresAt = _safeTime(s["expiresAt"]);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (expiresAt > 0) return now >= expiresAt;

    final createdAt = _safeTime(s["createdAt"]);
    if (createdAt == 0) return false;

    return (now - createdAt) > 24 * 60 * 60 * 1000;
  }

  List<Map<String, dynamic>> _filterExpired(List<Map<String, dynamic>> list) {
    return list.where((s) => !_isExpired(s)).toList();
  }

  String _storyId(Map<String, dynamic> story) {
    return (story["id"] ?? story["key"] ?? "").toString().trim();
  }

  @override
  void initState() {
    super.initState();

    _stories = _filterExpired(List<Map<String, dynamic>>.from(widget.stories));

    if (_stories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    currentIndex = widget.initialIndex;
    if (currentIndex >= _stories.length) currentIndex = 0;

    _pageController = PageController(initialPage: currentIndex);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _startProgress();
    _loadMyProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markSeen(_stories[currentIndex]);
      _startExpiryWatcher();
      _startTimeAgoUpdater();
    });
  }

  void _startTimeAgoUpdater() {
    _timeRefreshTimer?.cancel();
    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _startExpiryWatcher() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;

      final filtered = _filterExpired(_stories);

      if (filtered.length != _stories.length) {
        setState(() {
          _stories = filtered;
          if (currentIndex >= _stories.length) currentIndex = 0;
        });

        if (_stories.isEmpty) {
          Navigator.pop(context);
          return;
        }

        _pageController.jumpToPage(currentIndex);
      }
    });
  }

  Future<void> _loadMyProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await _usersRef.child(uid).get();
      if (snap.value is Map) {
        _myProfile = Map<String, dynamic>.from(snap.value as Map);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _profileLoaded = true;
      });
    }
  }

  void _startProgress() {
    _progressController.stop();
    _progressController.reset();
    _progressController.forward();
  }

  bool _isAdmin() {
    final role = (_myProfile["role"] ?? "").toString();
    return role == "admin";
  }

  bool _canManageStory(Map<String, dynamic> story) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    if (_isAdmin()) return true;

    final postedBy = (story["postedBy"] ?? "").toString();
    return postedBy == uid;
  }

  /// ✅ FIX: Always store the viewer data using the viewer profile
  Future<void> _markSeen(Map<String, dynamic> story) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final storyId = _storyId(story);
    if (storyId.isEmpty) return;

    try {
      // Fetch profile directly from users
      final userSnap = await _usersRef.child(uid).get();
      Map<String, dynamic> userData = {};

      if (userSnap.value is Map) {
        userData = Map<String, dynamic>.from(userSnap.value as Map);
      }

      final username = (userData["username"] ?? "").toString().trim();
      final name = (userData["name"] ?? "").toString().trim();
      final finalName =
          username.isNotEmpty ? username : (name.isNotEmpty ? name : "User");

      final role = (userData["role"] ?? "student").toString();

      await _storiesRef.child(storyId).child("views").child(uid).set({
        "uid": uid,
        "username": finalName,
        "name": finalName,
        "role": role,
        "seenAt": ServerValue.timestamp,
      });
    } catch (_) {}
  }

  void _nextStory() {
    if (_stories.isEmpty) return;

    if (currentIndex < _stories.length - 1) {
      setState(() => currentIndex++);
      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
      _startProgress();
      _markSeen(_stories[currentIndex]);
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_stories.isEmpty) return;

    if (currentIndex > 0) {
      setState(() => currentIndex--);
      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
      _startProgress();
      _markSeen(_stories[currentIndex]);
    }
  }

  Future<void> _deleteStory(Map<String, dynamic> story) async {
    final storyId = _storyId(story);
    if (storyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Story id missing, cannot delete ❌")),
      );
      return;
    }

    try {
      await _storiesRef.child(storyId).remove();

      final removedIndex = currentIndex;

      setState(() {
        _stories.removeWhere((s) => _storyId(s) == storyId);
      });

      if (_stories.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }

      if (removedIndex >= _stories.length) {
        currentIndex = _stories.length - 1;
      }

      _pageController.jumpToPage(currentIndex);
      _startProgress();
      _markSeen(_stories[currentIndex]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Story deleted ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  void _showDeleteConfirm(Map<String, dynamic> story) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Delete Story?",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "This will remove it for everyone.",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteStory(story);
                      },
                      child: const Text("Delete"),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  /// ✅ FIX: Viewers list fetches from users/{uid} if stored name is wrong
  void _showViewers(Map<String, dynamic> story) {
    final storyId = _storyId(story);
    if (storyId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      "Viewed by",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                StreamBuilder<DatabaseEvent>(
                  stream: _storiesRef.child(storyId).child("views").onValue,
                  builder: (context, snapshot) {
                    final raw = snapshot.data?.snapshot.value;

                    if (raw == null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          "No views yet 👀",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    }

                    if (raw is! Map) return const SizedBox.shrink();

                    final map = Map<dynamic, dynamic>.from(raw);

                    final viewers = <Map<String, dynamic>>[];

                    for (final e in map.entries) {
                      final uid = e.key.toString();
                      final vRaw = e.value;

                      Map<String, dynamic> viewData = {};
                      if (vRaw is Map) {
                        viewData = Map<String, dynamic>.from(vRaw);
                      }

                      viewData["uid"] = uid;
                      viewers.add(viewData);
                    }

                    viewers.sort((a, b) =>
                        _safeTime(b["seenAt"]).compareTo(_safeTime(a["seenAt"])));

                    return Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: viewers.length,
                        itemBuilder: (context, index) {
                          final v = viewers[index];
                          final uid = (v["uid"] ?? "").toString();

                          final seenAt = _safeTime(v["seenAt"]);
                          final role = (v["role"] ?? "").toString();
                          final isVerified = role == "admin";

                          return FutureBuilder<DataSnapshot>(
                            future: _usersRef.child(uid).get(),
                            builder: (context, snap) {
                              String displayName = "User";

                              if (snap.data?.value is Map) {
                                final userData =
                                    Map<String, dynamic>.from(snap.data!.value as Map);

                                final username =
                                    (userData["username"] ?? "").toString().trim();
                                final name =
                                    (userData["name"] ?? "").toString().trim();

                                displayName = username.isNotEmpty
                                    ? username
                                    : (name.isNotEmpty ? name : "User");
                              } else {
                                // fallback to stored viewData
                                final storedUsername =
                                    (v["username"] ?? "").toString().trim();
                                final storedName = (v["name"] ?? "").toString().trim();
                                displayName = storedUsername.isNotEmpty
                                    ? storedUsername
                                    : (storedName.isNotEmpty ? storedName : "User");
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.black,
                                      child: Icon(Icons.person,
                                          color: Colors.white, size: 18),
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
                                                  displayName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (isVerified)
                                                const Icon(Icons.verified,
                                                    size: 16,
                                                    color: Color(0xFF1D9BF0)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Seen • ${_timeAgo(seenAt)}",
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomOwnerActions(Map<String, dynamic> story) {
    final storyId = _storyId(story);
    if (storyId.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      right: 16,
      child: StreamBuilder<DatabaseEvent>(
        stream: _storiesRef.child(storyId).child("views").onValue,
        builder: (context, snapshot) {
          int viewCount = 0;
          final raw = snapshot.data?.snapshot.value;
          if (raw is Map) viewCount = raw.length;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _showViewers(story),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "$viewCount",
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
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _showDeleteConfirm(story),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 18),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _timeRefreshTimer?.cancel();
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final w = MediaQuery.of(context).size.width;
          final dx = details.globalPosition.dx;

          if (dx < w / 2) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _stories.length,
              onPageChanged: (i) {
                setState(() => currentIndex = i);
                _startProgress();
                _markSeen(_stories[currentIndex]);
              },
              itemBuilder: (context, index) {
                final s = _stories[index];

                final imageUrl = (s["imageUrl"] ?? "").toString();
                final title = (s["title"] ?? "").toString();

                final postedByName =
                    (s["postedByName"] ?? s["postedByUsername"] ?? "Unknown")
                        .toString();

                final createdAt = _safeTime(s["createdAt"]);
                final timeAgo = _timeAgo(createdAt);

                final role = (s["postedByRole"] ?? "").toString();
                final isVerified = role == "admin";

                final canManage = _canManageStory(s);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: imageUrl.isEmpty
                          ? Center(
                              child: Text(
                                "No image found ❌",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                );
                              },
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  "Story image failed to load ❌",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    if (title.trim().isNotEmpty)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 22,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      top: 46,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    postedByName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isVerified)
                                  const Icon(Icons.verified,
                                      size: 16, color: Color(0xFF1D9BF0)),
                                const SizedBox(width: 8),
                                Text(
                                  "• $timeAgo",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    if (_profileLoaded && canManage) _bottomOwnerActions(s),
                  ],
                );
              },
            ),

            Positioned(
              top: 20,
              left: 10,
              right: 10,
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  return Row(
                    children: List.generate(_stories.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: i < currentIndex
                                  ? 1
                                  : i == currentIndex
                                      ? _progressController.value
                                      : 0,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                      );
                    }),
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

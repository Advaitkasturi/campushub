import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/home_screen.dart';
import '../events/events_list_screen.dart';
import '../lost_found/lost_found_screen.dart';
import '../profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  final String userRole; // "admin" or "student"

  const MainShell({super.key, required this.userRole});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0; // ✅ Always start at Home

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(userRole: widget.userRole),
      EventsListScreen(userRole: widget.userRole),
      LostFoundScreen(userRole: widget.userRole),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages[currentIndex],

      // ✅ CLEAN WHITE BOTTOM NAV
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => setState(() => currentIndex = i),

          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,

          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,

          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_outlined),
              activeIcon: Icon(Icons.event),
              label: "Events",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: "Lost&Found",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

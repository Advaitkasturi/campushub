import 'package:flutter/material.dart';
import 'admin_attendance_screen.dart';
import 'student_attendance_screen.dart';

class AttendanceScreen extends StatelessWidget {
  final String userRole; // admin / student
  const AttendanceScreen({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    if (userRole == "admin") {
      return const AdminAttendanceScreen();
    }
    return const StudentAttendanceScreen();
  }
}

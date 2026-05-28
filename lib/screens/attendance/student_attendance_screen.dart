import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/app_colors.dart';
import '../../services/attendance_service.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final AttendanceService _service = AttendanceService();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  double _calcPercent(Map<String, bool> hourMap) {
    if (hourMap.isEmpty) return 0;
    final total = hourMap.length;
    final present = hourMap.values.where((v) => v == true).length;
    return (present / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Attendance",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Hour-wise attendance + percentage",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.subText,
                ),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _service.studentAttendanceStream(uid!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                      return Center(
                        child: Text(
                          "No attendance data yet",
                          style: GoogleFonts.poppins(
                            color: AppColors.subText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    final raw = snapshot.data!.snapshot.value;
                    if (raw is! Map) {
                      return const Center(child: Text("Invalid attendance format"));
                    }

                    // attendance/{date}/{hour}/{uid}: bool
                    final attendanceRoot = Map<dynamic, dynamic>.from(raw);

                    // Flatten into hourMap: "2026-01-23 hour1" => true/false
                    final Map<String, bool> myRecords = {};

                    attendanceRoot.forEach((dateKey, dateVal) {
                      if (dateVal is Map) {
                        final dateMap = Map<dynamic, dynamic>.from(dateVal);
                        dateMap.forEach((hourKey, hourVal) {
                          if (hourVal is Map) {
                            final hourMap = Map<dynamic, dynamic>.from(hourVal);
                            if (hourMap.containsKey(uid)) {
                              myRecords["$dateKey • $hourKey"] =
                                  (hourMap[uid] == true);
                            }
                          }
                        });
                      }
                    });

                    final percent = _calcPercent(myRecords);

                    return Column(
                      children: [
                        _PercentCard(percent: percent),
                        const SizedBox(height: 14),

                        Expanded(
                          child: myRecords.isEmpty
                              ? Center(
                                  child: Text(
                                    "No attendance marked yet",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.subText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ListView(
                                  children: myRecords.entries.map((e) {
                                    return _AttendanceRow(
                                      label: e.key,
                                      present: e.value,
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
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

class _PercentCard extends StatelessWidget {
  final double percent;
  const _PercentCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 100).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Overall Attendance",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$p%",
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final String label;
  final bool present;

  const _AttendanceRow({required this.label, required this.present});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: present ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              present ? "Present" : "Absent",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: present ? const Color(0xFF15803D) : const Color(0xFFBE123C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../services/attendance_service.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final AttendanceService _service = AttendanceService();

  String selectedDay = DateFormat("EEEE").format(DateTime.now());
  final List<String> days = const [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  final TextEditingController subjectCtrl = TextEditingController();
  final TextEditingController startCtrl = TextEditingController();
  final TextEditingController endCtrl = TextEditingController();

  String selectedHour = "1"; // hour slot number
  final List<String> hours = List.generate(8, (i) => "${i + 1}");

  @override
  void dispose() {
    subjectCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveHour() async {
    final subject = subjectCtrl.text.trim();
    final start = startCtrl.text.trim();
    final end = endCtrl.text.trim();

    if (subject.isEmpty || start.isEmpty || end.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all timetable fields")),
      );
      return;
    }

    await _service.setTimetableHour(
      day: selectedDay,
      hourKey: selectedHour,
      subject: subject,
      start: start,
      end: end,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Timetable updated")),
    );

    subjectCtrl.clear();
    startCtrl.clear();
    endCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final todayKey = _service.todayKey();

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Attendance Management",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Set timetable + mark hour-wise attendance",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.subText,
                ),
              ),
              const SizedBox(height: 14),

              // Timetable setup card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Set Timetable",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _DropdownBox(
                            label: "Day",
                            value: selectedDay,
                            items: days,
                            onChanged: (v) => setState(() => selectedDay = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DropdownBox(
                            label: "Hour",
                            value: selectedHour,
                            items: hours,
                            onChanged: (v) => setState(() => selectedHour = v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _Input(
                      hint: "Subject name (e.g., DSA)",
                      controller: subjectCtrl,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _Input(
                            hint: "Start (09:00)",
                            controller: startCtrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Input(
                            hint: "End (10:00)",
                            controller: endCtrl,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _saveHour,
                        child: Text(
                          "Save Timetable Hour",
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

              const SizedBox(height: 14),

              Text(
                "Mark Attendance (Today: $todayKey)",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _service.studentsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return Center(
                        child: Text(
                          "No students found",
                          style: GoogleFonts.poppins(
                            color: AppColors.subText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    final raw = snapshot.data!.snapshot.value;
                    if (raw is! Map) {
                      return const Center(child: Text("Invalid students format"));
                    }

                    final students = Map<dynamic, dynamic>.from(raw).entries
                        .map((e) {
                      final m = Map<String, dynamic>.from(e.value);
                      m["uid"] = e.key;
                      return m;
                    }).toList();

                    return ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, i) {
                        final s = students[i];
                        final uid = (s["uid"] ?? "").toString();
                        final name = (s["name"] ?? "Student").toString();
                        final email = (s["email"] ?? "").toString();

                        return _StudentMarkCard(
                          name: name,
                          email: email,
                          onPresent: () async {
                            await _service.markAttendance(
                              dateKey: todayKey,
                              hourKey: "hour$selectedHour",
                              studentUid: uid,
                              present: true,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Marked Present: $name")),
                            );
                          },
                          onAbsent: () async {
                            await _service.markAttendance(
                              dateKey: todayKey,
                              hourKey: "hour$selectedHour",
                              studentUid: uid,
                              present: false,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Marked Absent: $name")),
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

// ===================== UI Widgets =====================

class _DropdownBox extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownBox({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final String hint;
  final TextEditingController controller;

  const _Input({required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StudentMarkCard extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;

  const _StudentMarkCard({
    required this.name,
    required this.email,
    required this.onPresent,
    required this.onAbsent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.subText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onPresent,
                  child: Text(
                    "Present",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onAbsent,
                  child: Text(
                    "Absent",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

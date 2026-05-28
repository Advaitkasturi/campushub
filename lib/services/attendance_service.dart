import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String todayKey() {
    return DateFormat("yyyy-MM-dd").format(DateTime.now());
  }

  String weekdayKey() {
    return DateFormat("EEEE").format(DateTime.now()); // Monday...
  }

  // ================== TIMETABLE ==================
  Stream<DatabaseEvent> timetableStream(String day) {
    return _db.child("timetable").child(day).onValue;
  }

  Future<void> setTimetableHour({
    required String day,
    required String hourKey, // "1","2","3"
    required String subject,
    required String start,
    required String end,
  }) async {
    await _db.child("timetable").child(day).child(hourKey).set({
      "subject": subject,
      "start": start,
      "end": end,
      "updatedAt": ServerValue.timestamp,
    });
  }

  Future<void> deleteTimetableHour({
    required String day,
    required String hourKey,
  }) async {
    await _db.child("timetable").child(day).child(hourKey).remove();
  }

  // ================== STUDENTS ==================
  Stream<DatabaseEvent> studentsStream() {
    return _db.child("users").orderByChild("role").equalTo("student").onValue;
  }

  // ================== ATTENDANCE ==================
  Stream<DatabaseEvent> attendanceStreamForDay(String dateKey) {
    return _db.child("attendance").child(dateKey).onValue;
  }

  Future<void> markAttendance({
    required String dateKey, // yyyy-mm-dd
    required String hourKey, // "hour1"
    required String studentUid,
    required bool present,
  }) async {
    await _db
        .child("attendance")
        .child(dateKey)
        .child(hourKey)
        .child(studentUid)
        .set(present);
  }

  Stream<DatabaseEvent> studentAttendanceStream(String uid) {
    // For simplicity, read full attendance tree and filter in UI
    return _db.child("attendance").onValue;
  }
}

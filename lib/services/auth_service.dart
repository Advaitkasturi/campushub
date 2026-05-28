import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ---------------------------
  // SIGNUP (Email + Password)
  // ---------------------------
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = cred.user!.uid;

    // Store user in DB
    await _createUserIfNotExists(
      uid: uid,
      email: email.trim(),
      name: name.trim(),
      provider: "password",
    );

    return cred;
  }

  // ---------------------------
  // LOGIN (Email + Password)
  // ---------------------------
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = cred.user!.uid;

    // If user exists in Auth but not in DB, create it
    await _createUserIfNotExists(
      uid: uid,
      email: cred.user?.email ?? email.trim(),
      name: cred.user?.displayName ?? "",
      provider: "password",
    );

    return cred;
  }

  // ---------------------------
  // GOOGLE LOGIN
  // ---------------------------
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception("Google Sign-In cancelled");
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);

    final uid = userCred.user!.uid;

    await _createUserIfNotExists(
      uid: uid,
      email: userCred.user?.email ?? "",
      name: userCred.user?.displayName ?? "",
      provider: "google",
    );

    return userCred;
  }

  // ---------------------------
  // LOGOUT
  // ---------------------------
  Future<void> logout() async {
    await _auth.signOut();

    // Google signout only if user was signed in using google
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // ignore
    }
  }

  // ---------------------------
  // GET ROLE FROM DATABASE
  // ---------------------------
  Future<String> getUserRole(String uid) async {
    final snapshot = await _db.child("users").child(uid).child("role").get();

    if (snapshot.exists) {
      return snapshot.value.toString(); // admin / student
    }
    return "student";
  }

  // ---------------------------
  // GET USER DATA (name + email + role + EXTRA FIELDS)
  // ---------------------------
  Future<Map<String, dynamic>> getUserData(String uid) async {
    final snapshot = await _db.child("users").child(uid).get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      return {
        "uid": data["uid"] ?? uid,
        "name": data["name"] ?? "",
        "email": data["email"] ?? "",
        "role": data["role"] ?? "student",
        "provider": data["provider"] ?? "",
        "createdAt": data["createdAt"] ?? "",

        // ✅ EXTRA PROFILE DETAILS
        "phone": data["phone"] ?? "",
        "branch": data["branch"] ?? "",
        "year": data["year"] ?? "",
      };
    }

    return {
      "uid": uid,
      "name": "",
      "email": "",
      "role": "student",
      "provider": "",
      "createdAt": "",

      // ✅ EXTRA PROFILE DETAILS
      "phone": "",
      "branch": "",
      "year": "",
    };
  }

  // ---------------------------
  // ✅ UPDATE PROFILE (SAVE EDITED DETAILS)
  // ---------------------------
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
    required String branch,
    required String year,
  }) async {
    await _db.child("users").child(uid).update({
      "name": name,
      "phone": phone,
      "branch": branch,
      "year": year,
    });
  }

  // ---------------------------
  // HELPER: Create user in DB if not exists
  // ---------------------------
  Future<void> _createUserIfNotExists({
    required String uid,
    required String email,
    required String name,
    required String provider,
  }) async {
    final snap = await _db.child("users").child(uid).get();

    if (!snap.exists) {
      await _db.child("users").child(uid).set({
        "uid": uid,
        "name": name,
        "email": email,
        "role": "student",
        "provider": provider,
        "createdAt": DateTime.now().toIso8601String(),

        // ✅ default extra fields (optional)
        "phone": "",
        "branch": "",
        "year": "",
      });
    }
  }
}

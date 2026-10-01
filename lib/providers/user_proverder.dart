import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final String studentInfo;
  final String avatarEmoji;

  /// Path to a profile photo stored inside the app's own documents folder.
  /// When null, the avatar falls back to [avatarEmoji].
  final String? avatarImagePath;

  const UserProfile({
    required this.name,
    required this.studentInfo,
    required this.avatarEmoji,
    this.avatarImagePath,
  });

  UserProfile copyWith({
    String? name,
    String? studentInfo,
    String? avatarEmoji,
    String? avatarImagePath,
    bool clearAvatarImage = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      studentInfo: studentInfo ?? this.studentInfo,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarImagePath: clearAvatarImage
          ? null
          : (avatarImagePath ?? this.avatarImagePath),
    );
  }
}

class UserProfileProvider with ChangeNotifier {
  UserProfile _user = const UserProfile(
    name: 'Alex',
    studentInfo: 'BSIT Student',
    avatarEmoji: '👨‍💻',
  );

  UserProfile get user => _user;

  static const _prefsKey = 'user_profile_v1';
  static const _onboardedKey = 'has_onboarded_v1';

  bool _hasOnboarded = false;
  bool _isLoaded = false;

  /// True once the first-launch setup has been completed.
  bool get hasOnboarded => _hasOnboarded;

  /// False until [load] has finished reading saved data. The app shows a
  /// splash until then so the wrong screen never flashes.
  bool get isLoaded => _isLoaded;

  /// Call once at launch to restore the saved profile.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasOnboarded = prefs.getBool(_onboardedKey) ?? false;

      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final d = jsonDecode(raw) as Map<String, dynamic>;

        // Older saves also had a 'monthlyBudget' key; the budget now lives in
        // ExpenseProvider only, so that key is simply ignored here.
        var imagePath = d['avatarImagePath'] as String?;
        if (imagePath != null && !File(imagePath).existsSync()) {
          imagePath = null; // photo was deleted/cleared: fall back to the emoji
        }

        _user = UserProfile(
          name: d['name'] as String? ?? _user.name,
          studentInfo: d['studentInfo'] as String? ?? _user.studentInfo,
          avatarEmoji: d['avatarEmoji'] as String? ?? _user.avatarEmoji,
          avatarImagePath: imagePath,
        );
      }
    } catch (e) {
      debugPrint('Could not load profile: $e');
    } finally {
      // Always flip this, even if loading failed, or the app would sit on
      // the splash screen forever.
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'name': _user.name,
          'studentInfo': _user.studentInfo,
          'avatarEmoji': _user.avatarEmoji,
          'avatarImagePath': _user.avatarImagePath,
        }),
      );
      await prefs.setBool(_onboardedKey, _hasOnboarded);
    } catch (e) {
      debugPrint('Could not save profile: $e');
    }
  }

  /// Finishes first-launch setup: saves the profile the person chose and
  /// marks onboarding as done (which makes the app move on to the main
  /// screens). Returns false only if a chosen photo could not be saved; the
  /// rest of the profile is still saved in that case.
  Future<bool> completeOnboarding({
    required String name,
    String studentInfo = '',
    required String avatarEmoji,
    String? photoPath,
  }) async {
    _user = _user.copyWith(
      name: name.trim(),
      studentInfo: studentInfo.trim().isNotEmpty
          ? studentInfo.trim()
          : 'Student',
      avatarEmoji: avatarEmoji,
    );

    var photoOk = true;
    if (photoPath != null) {
      // Copies the photo into app storage and saves the profile.
      photoOk = await setAvatarPhoto(photoPath);
    }

    _hasOnboarded = true;
    await _save();
    notifyListeners();
    return photoOk;
  }

  void updateProfile({String? name, String? studentInfo, String? avatarEmoji}) {
    _user = _user.copyWith(
      name: name,
      studentInfo: studentInfo,
      avatarEmoji: avatarEmoji,
    );
    notifyListeners();
    _save();
  }

  /// The parts of the profile a text backup can carry. The photo is left out:
  /// it's a file in this device's app storage, and the path in the backup
  /// would mean nothing anywhere else.
  Map<String, dynamic> exportProfile() {
    return {
      'name': _user.name,
      'studentInfo': _user.studentInfo,
      'avatarEmoji': _user.avatarEmoji,
    };
  }

  /// Restores name / student info / avatar emoji from a backup. Any photo
  /// already set here is kept — see [exportProfile]. Returns false if the file
  /// had no usable name, in which case nothing is changed.
  bool applyImportedProfile(Map<String, dynamic> data) {
    final name = (data['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return false;

    final emoji = (data['avatarEmoji'] as String?)?.trim();
    _user = _user.copyWith(
      name: name,
      studentInfo: (data['studentInfo'] as String?)?.trim(),
      avatarEmoji: (emoji == null || emoji.isEmpty) ? null : emoji,
    );
    notifyListeners();
    _save();
    return true;
  }

  /// Copies the picked image into the app's documents folder (so it survives
  /// gallery changes / cache clears) and uses that copy as the profile photo.
  /// Returns false if the copy failed.
  Future<bool> setAvatarPhoto(String sourcePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      var ext = p.extension(sourcePath).toLowerCase();
      if (ext.isEmpty) ext = '.jpg';
      // A fresh file name each time so Flutter's image cache never shows a
      // stale photo.
      final dest = p.join(
        dir.path,
        'avatar_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(sourcePath).copy(dest);

      await _deleteStoredPhoto();
      _user = _user.copyWith(avatarImagePath: dest);
      notifyListeners();
      await _save();
      return true;
    } catch (e) {
      debugPrint('Could not save profile photo: $e');
      return false;
    }
  }

  /// Removes the photo; the avatar goes back to the chosen emoji.
  Future<void> removeAvatarPhoto() async {
    await _deleteStoredPhoto();
    _user = _user.copyWith(clearAvatarImage: true);
    notifyListeners();
    await _save();
  }

  Future<void> _deleteStoredPhoto() async {
    final old = _user.avatarImagePath;
    if (old == null) return;
    try {
      final f = File(old);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Could not delete old profile photo: $e');
    }
  }
}

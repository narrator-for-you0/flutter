import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final String studentInfo;
  final double monthlyBudget;
  final String avatarEmoji;

  const UserProfile({
    required this.name,
    required this.studentInfo,
    required this.monthlyBudget,
    required this.avatarEmoji,
  });

  UserProfile copyWith({
    String? name,
    String? studentInfo,
    double? monthlyBudget,
    String? avatarEmoji,
  }) {
    return UserProfile(
      name: name ?? this.name,
      studentInfo: studentInfo ?? this.studentInfo,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    );
  }
}

class UserProfileProvider with ChangeNotifier {
  UserProfile _user = const UserProfile(
    name: 'Alex',
    studentInfo: 'BSIT Student',
    monthlyBudget: 6000.0,
    avatarEmoji: '👨‍💻',
  );

  UserProfile get user => _user;

  static const _prefsKey = 'user_profile_v1';

  /// Call once at launch to restore the saved profile.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      _user = UserProfile(
        name: d['name'] as String? ?? _user.name,
        studentInfo: d['studentInfo'] as String? ?? _user.studentInfo,
        monthlyBudget: (d['monthlyBudget'] as num?)?.toDouble() ?? _user.monthlyBudget,
        avatarEmoji: d['avatarEmoji'] as String? ?? _user.avatarEmoji,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load profile: $e');
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
          'monthlyBudget': _user.monthlyBudget,
          'avatarEmoji': _user.avatarEmoji,
        }),
      );
    } catch (e) {
      debugPrint('Could not save profile: $e');
    }
  }

  void updateProfile({
    String? name,
    String? studentInfo,
    double? monthlyBudget,
    String? avatarEmoji,
  }) {
    _user = _user.copyWith(
      name: name,
      studentInfo: studentInfo,
      monthlyBudget: monthlyBudget,
      avatarEmoji: avatarEmoji,
    );
    notifyListeners();
    _save();
  }
}

import 'package:flutter/material.dart';

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
  }
}

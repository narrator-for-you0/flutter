import 'package:flutter/material.dart';

class UserProfile {
  String name;
  String studentInfo;
  double monthlyBudget;
  String avatarEmoji;

  UserProfile({
    required this.name,
    required this.studentInfo,
    required this.monthlyBudget,
    required this.avatarEmoji,
  });
}

class UserProfileProvider extends ChangeNotifier {
  UserProfile _user = UserProfile(
    name: 'IT Student',
    studentInfo: 'BS Information Technology',
    monthlyBudget: 3000.0,
    avatarEmoji: '👨‍💻',
  );

  UserProfile get user => _user;

  void updateProfile({
    String? name,
    String? studentInfo,
    double? monthlyBudget,
    String? avatarEmoji,
  }) {
    _user = UserProfile(
      name: name ?? _user.name,
      studentInfo: studentInfo ?? _user.studentInfo,
      monthlyBudget: monthlyBudget ?? _user.monthlyBudget,
      avatarEmoji: avatarEmoji ?? _user.avatarEmoji,
    );
    notifyListeners();
  }

  void updateBudget(double newBudget) {
    _user.monthlyBudget = newBudget;
    notifyListeners();
  }
}
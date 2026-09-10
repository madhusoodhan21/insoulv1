import 'package:flutter/foundation.dart';

/// User profile model for storing user-specific settings and data.
class UserProfile with ChangeNotifier {
  String? name;
  int? age;
  double? height; // in cm
  double? weight; // in kg

  UserProfile({
    this.name,
    this.age,
    this.height,
    this.weight,
  });

  void updateProfile({
    String? name,
    int? age,
    double? height,
    double? weight,
  }) {
    if (name != null) this.name = name;
    if (age != null) this.age = age;
    if (height != null) this.height = height;
    if (weight != null) this.weight = weight;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';

class BloodSugarEntry {
  final String id;
  final int value; // mg/dL
  final DateTime timestamp;
  final String context; // Fasting, Before meal, After meal, Random
  final String? note;

  BloodSugarEntry({
    required this.id,
    required this.value,
    required this.timestamp,
    required this.context,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
      'note': note,
    };
  }

  // For Supabase insertion (without id, let database generate it)
  Map<String, dynamic> toSupabaseInsert(String userId) {
    return {
      'user_id': userId,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
      'note': note,
    };
  }

  factory BloodSugarEntry.fromJson(Map<String, dynamic> json) {
    return BloodSugarEntry(
      id: json['id'],
      value: json['value'],
      timestamp: DateTime.parse(json['timestamp']),
      context: json['context'],
      note: json['note'],
    );
  }

  // Factory for Supabase data
  factory BloodSugarEntry.fromSupabase(Map<String, dynamic> json) {
    return BloodSugarEntry(
      id: json['id'],
      value: json['value'],
      timestamp: DateTime.parse(json['timestamp']),
      context: json['context'],
      note: json['note'],
    );
  }

  // Get color based on value
  Color getColor() {
    if (value < 70 || value > 180) {
      return Colors.red; // High/Low
    } else if (value >= 140 && value <= 180) {
      return Colors.orange; // Borderline high
    } else {
      return Colors.green; // Normal
    }
  }

  // Get status text
  String getStatus() {
    if (value < 70) {
      return 'Low';
    } else if (value > 180) {
      return 'High';
    } else if (value >= 140) {
      return 'Borderline High';
    } else {
      return 'Normal';
    }
  }
}
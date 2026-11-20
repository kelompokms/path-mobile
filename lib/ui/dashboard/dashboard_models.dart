import 'dart:math' as math;

import 'package:path_mobile/data/kelas/kelas_model.dart' as km;
import 'package:path_mobile/ui/core/class_card.dart';

class GuruSubmissionSummary {
  final ClassItem classItem;
  final km.PostinganModel post;
  final int submissionCount;
  final int totalStudents;
  final String latestStudentName;

  const GuruSubmissionSummary({
    required this.classItem,
    required this.post,
    required this.submissionCount,
    this.totalStudents = 0,
    this.latestStudentName = '',
  });

  double? get completionRate {
    if (totalStudents <= 0) return null;
    final denom = math.max(totalStudents, submissionCount);
    return (submissionCount / denom).clamp(0.0, 1.0);
  }
}

class MuridTaskSummary {
  final ClassItem classItem;
  final km.PostinganModel post;
  final bool submitted;
  final int? nilai;

  const MuridTaskSummary({
    required this.classItem,
    required this.post,
    required this.submitted,
    this.nilai,
  });
}

class GuruClassProgress {
  final ClassItem classItem;
  final int studentCount;
  final int taskCount;
  final int submissionCount;
  final int expectedSubmissions;

  const GuruClassProgress({
    required this.classItem,
    required this.studentCount,
    required this.taskCount,
    required this.submissionCount,
    required this.expectedSubmissions,
  });

  double? get completionRate {
    if (expectedSubmissions <= 0) return null;
    return (submissionCount / expectedSubmissions).clamp(0.0, 1.0);
  }
}

class DailySubmissionBucket {
  final DateTime date;
  final String label;
  final int count;
  final bool isToday;

  const DailySubmissionBucket({
    required this.date,
    required this.label,
    required this.count,
    required this.isToday,
  });
}

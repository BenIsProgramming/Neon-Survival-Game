import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreEntry {
  final String name;
  final int score;
  final int playersCount;
  final String difficulty;
  final bool isHardcore;
  final DateTime date;

  ScoreEntry({
    required this.name,
    required this.score,
    required this.playersCount,
    this.difficulty = 'normal',
    this.isHardcore = false,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'playersCount': playersCount,
    'difficulty': difficulty,
    'isHardcore': isHardcore,
    'date': date.toIso8601String(),
  };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) => ScoreEntry(
    name: json['name'] as String,
    score: json['score'] as int,
    playersCount: json['playersCount'] as int? ?? 1,
    difficulty: json['difficulty'] as String? ?? 'normal',
    isHardcore: json['isHardcore'] as bool? ?? false,
    date: DateTime.parse(json['date'] as String),
  );
}

class LeaderboardManager {
  static const String _storageKey = 'neon_survival_high_scores';

  static Future<List<ScoreEntry>> getHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data == null) {
      // Default placeholder high scores for retro feel
      return [
        ScoreEntry(name: 'APEX', score: 5000, playersCount: 1, difficulty: 'hard', isHardcore: true, date: DateTime.now()),
        ScoreEntry(name: 'NEON', score: 3000, playersCount: 2, difficulty: 'normal', isHardcore: false, date: DateTime.now()),
        ScoreEntry(name: 'GLOW', score: 1000, playersCount: 1, difficulty: 'easy', isHardcore: false, date: DateTime.now()),
      ];
    }
    try {
      final List decoded = json.decode(data);
      final list = decoded.map((item) => ScoreEntry.fromJson(item)).toList();
      list.sort((a, b) => b.score.compareTo(a.score));
      return list;
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveScore(String name, int score, int playersCount, String difficulty, bool isHardcore) async {
    final scores = await getHighScores();
    scores.add(ScoreEntry(
      name: name.isEmpty ? 'ANON' : name.toUpperCase(),
      score: score,
      playersCount: playersCount,
      difficulty: difficulty,
      isHardcore: isHardcore,
      date: DateTime.now(),
    ));
    scores.sort((a, b) => b.score.compareTo(a.score));
    
    // Keep top 20 scores now that we can filter them! Let's expand this limit from 10 to 30.
    final top30 = scores.take(30).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(top30.map((e) => e.toJson()).toList()));
  }
}

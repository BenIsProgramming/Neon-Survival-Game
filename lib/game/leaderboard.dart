import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreEntry {
  final String name;
  final int score;
  final int playersCount;
  final DateTime date;

  ScoreEntry({
    required this.name,
    required this.score,
    required this.playersCount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'playersCount': playersCount,
    'date': date.toIso8601String(),
  };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) => ScoreEntry(
    name: json['name'] as String,
    score: json['score'] as int,
    playersCount: json['playersCount'] as int? ?? 1,
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
        ScoreEntry(name: 'APEX', score: 5000, playersCount: 1, date: DateTime.now()),
        ScoreEntry(name: 'NEON', score: 3000, playersCount: 2, date: DateTime.now()),
        ScoreEntry(name: 'GLOW', score: 1000, playersCount: 1, date: DateTime.now()),
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

  static Future<void> saveScore(String name, int score, int playersCount) async {
    final scores = await getHighScores();
    scores.add(ScoreEntry(
      name: name.isEmpty ? 'ANON' : name.toUpperCase(),
      score: score,
      playersCount: playersCount,
      date: DateTime.now(),
    ));
    scores.sort((a, b) => b.score.compareTo(a.score));
    
    // Keep top 10 scores
    final top10 = scores.take(10).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(top10.map((e) => e.toJson()).toList()));
  }
}

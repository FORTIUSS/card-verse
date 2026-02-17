import 'package:cardverses/domain/entities/card_entity.dart';
import 'package:equatable/equatable.dart';

class Player extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<CardModel> hand;
  final int score;
  final bool isOnline;
  final bool hasCalledUno;
  final DateTime? lastActive;

  const Player({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.hand,
    this.score = 0,
    this.isOnline = true,
    this.hasCalledUno = false,
    this.lastActive,
  });

  Player copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    List<CardModel>? hand,
    int? score,
    bool? isOnline,
    bool? hasCalledUno,
    DateTime? lastActive,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hand: hand ?? this.hand,
      score: score ?? this.score,
      isOnline: isOnline ?? this.isOnline,
      hasCalledUno: hasCalledUno ?? this.hasCalledUno,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'hand': hand.map((c) => c.toJson()).toList(),
      'score': score,
      'isOnline': isOnline,
      'hasCalledUno': hasCalledUno,
      'lastActive': lastActive?.toIso8601String(),
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      hand: (json['hand'] as List)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      score: json['score'] as int,
      isOnline: json['isOnline'] as bool,
      hasCalledUno: json['hasCalledUno'] as bool,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, hand.length, score, isOnline, hasCalledUno];
}

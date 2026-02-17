import 'package:cardverses/domain/entities/card_entity.dart';
import 'package:cardverses/domain/entities/game_rules_entity.dart';
import 'package:cardverses/domain/entities/player_entity.dart';
import 'package:equatable/equatable.dart';

class Game extends Equatable {
  final String id;
  final GameStatus status;
  final List<Player> players;
  final int currentPlayerIndex;
  final GameDirection direction;
  final List<CardModel> drawPile;
  final List<CardModel> discardPile;
  final CardColor? currentWildColor;
  final int cardsToDraw;
  final bool isStackingActive;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? winnerId;
  final HouseRules houseRules;
  final ScoreMode scoreMode;
  final Map<String, int> playerScores;

  const Game({
    required this.id,
    required this.status,
    required this.players,
    required this.currentPlayerIndex,
    required this.direction,
    required this.drawPile,
    required this.discardPile,
    this.currentWildColor,
    this.cardsToDraw = 0,
    this.isStackingActive = false,
    required this.startedAt,
    this.endedAt,
    this.winnerId,
    required this.houseRules,
    this.scoreMode = ScoreMode.cumulative,
    this.playerScores = const {},
  });

  Player get currentPlayer => players[currentPlayerIndex];
  
  CardModel? get topDiscard => discardPile.isNotEmpty ? discardPile.last : null;
  
  bool get isClockwise => direction == GameDirection.clockwise;
  
  int get nextPlayerIndex {
    if (isClockwise) {
      return (currentPlayerIndex + 1) % players.length;
    } else {
      return (currentPlayerIndex - 1 + players.length) % players.length;
    }
  }

  Game copyWith({
    String? id,
    GameStatus? status,
    List<Player>? players,
    int? currentPlayerIndex,
    GameDirection? direction,
    List<CardModel>? drawPile,
    List<CardModel>? discardPile,
    CardColor? currentWildColor,
    int? cardsToDraw,
    bool? isStackingActive,
    DateTime? startedAt,
    DateTime? endedAt,
    String? winnerId,
    HouseRules? houseRules,
    ScoreMode? scoreMode,
    Map<String, int>? playerScores,
  }) {
    return Game(
      id: id ?? this.id,
      status: status ?? this.status,
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      direction: direction ?? this.direction,
      drawPile: drawPile ?? this.drawPile,
      discardPile: discardPile ?? this.discardPile,
      currentWildColor: currentWildColor ?? this.currentWildColor,
      cardsToDraw: cardsToDraw ?? this.cardsToDraw,
      isStackingActive: isStackingActive ?? this.isStackingActive,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      winnerId: winnerId ?? this.winnerId,
      houseRules: houseRules ?? this.houseRules,
      scoreMode: scoreMode ?? this.scoreMode,
      playerScores: playerScores ?? this.playerScores,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status.name,
      'players': players.map((p) => p.toJson()).toList(),
      'currentPlayerIndex': currentPlayerIndex,
      'direction': direction.name,
      'drawPile': drawPile.map((c) => c.toJson()).toList(),
      'discardPile': discardPile.map((c) => c.toJson()).toList(),
      'currentWildColor': currentWildColor?.name,
      'cardsToDraw': cardsToDraw,
      'isStackingActive': isStackingActive,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'winnerId': winnerId,
      'houseRules': houseRules.toJson(),
      'scoreMode': scoreMode.name,
      'playerScores': playerScores,
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      status: GameStatus.values.byName(json['status'] as String),
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      direction: GameDirection.values.byName(json['direction'] as String),
      drawPile: (json['drawPile'] as List)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      discardPile: (json['discardPile'] as List)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      currentWildColor: json['currentWildColor'] != null
          ? CardColor.values.byName(json['currentWildColor'] as String)
          : null,
      cardsToDraw: json['cardsToDraw'] as int,
      isStackingActive: json['isStackingActive'] as bool,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      winnerId: json['winnerId'] as String?,
      houseRules: HouseRules.fromJson(json['houseRules'] as Map<String, dynamic>),
      scoreMode: ScoreMode.values.byName(json['scoreMode'] as String),
      playerScores: Map<String, int>.from(json['playerScores'] as Map),
    );
  }

  @override
  List<Object?> get props => [
        id,
        status,
        players,
        currentPlayerIndex,
        direction,
        drawPile.length,
        discardPile.length,
        currentWildColor,
        cardsToDraw,
        isStackingActive,
        winnerId,
      ];
}

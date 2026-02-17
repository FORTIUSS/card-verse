import 'package:cardverses/domain/entities/game_rules_entity.dart';
import 'package:cardverses/domain/entities/player_entity.dart';
import 'package:equatable/equatable.dart';

enum RoomType {
  public,
  private,
}

enum RoomStatus {
  waiting,
  playing,
  finished,
  closed,
}

class Room extends Equatable {
  final String id;
  final String code;
  final String name;
  final RoomType type;
  final RoomStatus status;
  final Player host;
  final List<Player> players;
  final int maxPlayers;
  final int minPlayers;
  final HouseRules houseRules;
  final DateTime createdAt;
  final DateTime? startedAt;
  final String? gameId;
  final Map<String, dynamic> metadata;

  const Room({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.status,
    required this.host,
    required this.players,
    this.maxPlayers = 10,
    this.minPlayers = 2,
    required this.houseRules,
    required this.createdAt,
    this.startedAt,
    this.gameId,
    this.metadata = const {},
  });

  bool get isFull => players.length >= maxPlayers;
  bool get canStart => players.length >= minPlayers && status == RoomStatus.waiting;
  bool get isPrivate => type == RoomType.private;
  
  int get playerCount => players.length;

  Room copyWith({
    String? id,
    String? code,
    String? name,
    RoomType? type,
    RoomStatus? status,
    Player? host,
    List<Player>? players,
    int? maxPlayers,
    int? minPlayers,
    HouseRules? houseRules,
    DateTime? createdAt,
    DateTime? startedAt,
    String? gameId,
    Map<String, dynamic>? metadata,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      host: host ?? this.host,
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      minPlayers: minPlayers ?? this.minPlayers,
      houseRules: houseRules ?? this.houseRules,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      gameId: gameId ?? this.gameId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'type': type.name,
      'status': status.name,
      'host': host.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
      'maxPlayers': maxPlayers,
      'minPlayers': minPlayers,
      'houseRules': houseRules.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'gameId': gameId,
      'metadata': metadata,
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      type: RoomType.values.byName(json['type'] as String),
      status: RoomStatus.values.byName(json['status'] as String),
      host: Player.fromJson(json['host'] as Map<String, dynamic>),
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      maxPlayers: json['maxPlayers'] as int,
      minPlayers: json['minPlayers'] as int,
      houseRules: HouseRules.fromJson(json['houseRules'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      gameId: json['gameId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  List<Object?> get props => [
        id,
        code,
        status,
        players.length,
        gameId,
      ];
}

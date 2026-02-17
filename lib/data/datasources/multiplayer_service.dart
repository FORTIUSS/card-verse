import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cardverses/domain/entities/card_entity.dart';
import 'package:cardverses/domain/entities/game_entity.dart';
import 'package:cardverses/domain/entities/game_rules_entity.dart';
import 'package:cardverses/domain/entities/player_entity.dart';
import 'package:cardverses/domain/entities/room_entity.dart';
import 'package:cardverses/domain/usecases/deck_manager.dart';
import 'package:cardverses/domain/usecases/game_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';

class MultiplayerService {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;
  final GameEngine _gameEngine;
  final DeckManager _deckManager;
  IO.Socket? _socket;
  
  final _uuid = const Uuid();
  final _random = Random();
  
  final _gameUpdatesController = StreamController<Game>.broadcast();
  final _roomUpdatesController = StreamController<Room>.broadcast();

  MultiplayerService({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
    required GameEngine gameEngine,
    required DeckManager deckManager,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? FirebaseDatabase.instance,
        _gameEngine = gameEngine,
        _deckManager = deckManager;

  Stream<Game> get gameUpdates => _gameUpdatesController.stream;
  Stream<Room> get roomUpdates => _roomUpdatesController.stream;

  void connect(String serverUrl) {
    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket?.on('game_update', (data) {
      final game = Game.fromJson(jsonDecode(data));
      _gameUpdatesController.add(game);
    });

    _socket?.on('room_update', (data) {
      final room = Room.fromJson(jsonDecode(data));
      _roomUpdatesController.add(room);
    });

    _socket?.onConnect((_) {
      print('Connected to multiplayer server');
    });

    _socket?.onDisconnect((_) {
      print('Disconnected from multiplayer server');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  Future<Room> createRoom({
    required Player host,
    required String name,
    RoomType type = RoomType.public,
    int maxPlayers = 10,
    HouseRules? houseRules,
  }) async {
    final room = Room(
      id: _uuid.v4(),
      code: _generateRoomCode(),
      name: name,
      type: type,
      status: RoomStatus.waiting,
      host: host,
      players: [host],
      maxPlayers: maxPlayers,
      houseRules: houseRules ?? const HouseRules(),
      createdAt: DateTime.now(),
    );

    await _firestore.collection('rooms').doc(room.id).set(room.toJson());
    
    // Also store in Realtime Database for faster access
    await _database.ref('rooms/${room.id}').set(room.toJson());

    return room;
  }

  Future<Room> joinRoom(String code, Player player) async {
    final query = await _firestore
        .collection('rooms')
        .where('code', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: RoomStatus.waiting.name)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Room not found or not joinable');
    }

    final roomDoc = query.docs.first;
    final room = Room.fromJson(roomDoc.data());

    if (room.isFull) {
      throw Exception('Room is full');
    }

    if (room.players.any((p) => p.id == player.id)) {
      throw Exception('You are already in this room');
    }

    final updatedPlayers = List<Player>.from(room.players)..add(player);
    final updatedRoom = room.copyWith(players: updatedPlayers);

    await roomDoc.reference.update({'players': updatedPlayers.map((p) => p.toJson()).toList()});
    await _database.ref('rooms/${room.id}').update({
      'players': updatedPlayers.map((p) => p.toJson()).toList()
    });

    _socket?.emit('join_room', room.id);

    return updatedRoom;
  }

  Future<void> leaveRoom(String roomId, String playerId) async {
    final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) return;

    final room = Room.fromJson(roomDoc.data()!);
    final updatedPlayers = room.players.where((p) => p.id != playerId).toList();

    if (updatedPlayers.isEmpty) {
      // Close the room if no players left
      await roomDoc.reference.update({'status': RoomStatus.closed.name});
      await _database.ref('rooms/$roomId').remove();
    } else {
      // Transfer host if host left
      Player newHost = room.host;
      if (room.host.id == playerId && updatedPlayers.isNotEmpty) {
        newHost = updatedPlayers.first;
      }

      await roomDoc.reference.update({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'host': newHost.toJson(),
      });
      await _database.ref('rooms/$roomId').update({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'host': newHost.toJson(),
      });
    }

    _socket?.emit('leave_room', roomId);
  }

  Future<Game> startGame(String roomId) async {
    final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) {
      throw Exception('Room not found');
    }

    final room = Room.fromJson(roomDoc.data()!);
    
    if (room.players.length < room.minPlayers) {
      throw Exception('Not enough players to start');
    }

    // Create new game
    final game = _gameEngine.createNewGame(
      players: room.players,
      houseRules: room.houseRules,
    );

    // Update room
    final updatedRoom = room.copyWith(
      status: RoomStatus.playing,
      startedAt: DateTime.now(),
      gameId: game.id,
    );

    await _firestore.collection('rooms').doc(roomId).update(updatedRoom.toJson());
    await _firestore.collection('games').doc(game.id).set(game.toJson());
    
    await _database.ref('rooms/$roomId').update(updatedRoom.toJson());
    await _database.ref('games/${game.id}').set(game.toJson());

    _socket?.emit('game_started', jsonEncode(game.toJson()));

    return game;
  }

  Future<Game> playCard({
    required String gameId,
    required String playerId,
    required CardModel card,
    CardColor? selectedColor,
  }) async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    if (!gameDoc.exists) {
      throw Exception('Game not found');
    }

    final game = Game.fromJson(gameDoc.data()!);
    
    final updatedGame = _gameEngine.playCard(
      game,
      playerId,
      card,
      selectedColor: selectedColor,
    );

    await _updateGameState(gameId, updatedGame);
    
    return updatedGame;
  }

  Future<Game> drawCard(String gameId, String playerId) async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    if (!gameDoc.exists) {
      throw Exception('Game not found');
    }

    final game = Game.fromJson(gameDoc.data()!);
    final updatedGame = _gameEngine.drawCard(game, playerId);

    await _updateGameState(gameId, updatedGame);
    
    return updatedGame;
  }

  Future<Game> callUno(String gameId, String playerId) async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    if (!gameDoc.exists) {
      throw Exception('Game not found');
    }

    final game = Game.fromJson(gameDoc.data()!);
    final updatedGame = _gameEngine.callUno(game, playerId);

    await _updateGameState(gameId, updatedGame);
    
    return updatedGame;
  }

  Future<Game> catchUnoFailure(String gameId, String targetPlayerId) async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    if (!gameDoc.exists) {
      throw Exception('Game not found');
    }

    final game = Game.fromJson(gameDoc.data()!);
    final updatedGame = _gameEngine.catchUnoFailure(game, targetPlayerId);

    await _updateGameState(gameId, updatedGame);
    
    return updatedGame;
  }

  Future<void> _updateGameState(String gameId, Game game) async {
    await _firestore.collection('games').doc(gameId).update(game.toJson());
    await _database.ref('games/$gameId').set(game.toJson());
    
    _socket?.emit('game_update', jsonEncode(game.toJson()));
  }

  Stream<Room> listenToRoom(String roomId) {
    return _database.ref('rooms/$roomId').onValue.map((event) {
      if (event.snapshot.value == null) {
        throw Exception('Room not found');
      }
      return Room.fromJson(Map<String, dynamic>.from(event.snapshot.value as Map));
    });
  }

  Stream<Game> listenToGame(String gameId) {
    return _database.ref('games/$gameId').onValue.map((event) {
      if (event.snapshot.value == null) {
        throw Exception('Game not found');
      }
      return Game.fromJson(Map<String, dynamic>.from(event.snapshot.value as Map));
    });
  }

  Future<List<Room>> getPublicRooms() async {
    final query = await _firestore
        .collection('rooms')
        .where('type', isEqualTo: RoomType.public.name)
        .where('status', isEqualTo: RoomStatus.waiting.name)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return query.docs.map((doc) => Room.fromJson(doc.data())).toList();
  }

  void dispose() {
    _gameUpdatesController.close();
    _roomUpdatesController.close();
    disconnect();
  }
}

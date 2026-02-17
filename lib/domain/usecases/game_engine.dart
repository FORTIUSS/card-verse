import 'package:cardverses/domain/entities/card_entity.dart';
import 'package:cardverses/domain/entities/game_entity.dart';
import 'package:cardverses/domain/entities/game_rules_entity.dart';
import 'package:cardverses/domain/entities/player_entity.dart';
import 'package:cardverses/domain/usecases/deck_manager.dart';
import 'package:uuid/uuid.dart';

class GameEngine {
  final DeckManager _deckManager;
  final _uuid = const Uuid();

  GameEngine(this._deckManager);

  Game createNewGame({
    required List<Player> players,
    required HouseRules houseRules,
    ScoreMode scoreMode = ScoreMode.cumulative,
  }) {
    // Create and shuffle deck
    var deck = _deckManager.createFullDeck();
    deck = _deckManager.shuffle(deck);
    
    // Deal 7 cards to each player
    final hands = _deckManager.dealCards(deck, players.length, 7);
    
    // Update players with their hands
    final updatedPlayers = <Player>[];
    for (int i = 0; i < players.length; i++) {
      updatedPlayers.add(players[i].copyWith(hand: hands[i]));
    }
    
    // Find first non-wild card for discard pile
    CardModel firstDiscard;
    int discardIndex = 0;
    while (discardIndex < deck.length) {
      final card = deck[discardIndex];
      if (!card.isWildCard) {
        firstDiscard = card;
        deck.removeAt(discardIndex);
        break;
      }
      discardIndex++;
    }
    // If all remaining are wild, just use the first one
    firstDiscard = deck.removeAt(0);
    
    // Handle special first cards
    CardColor? wildColor;
    int currentPlayerIndex = 0;
    GameDirection direction = GameDirection.clockwise;
    int cardsToDraw = 0;
    
    if (firstDiscard.type == CardType.skip) {
      currentPlayerIndex = 1;
    } else if (firstDiscard.type == CardType.reverse) {
      direction = GameDirection.counterClockwise;
    } else if (firstDiscard.type == CardType.drawTwo) {
      cardsToDraw = 2;
    }
    
    return Game(
      id: _uuid.v4(),
      status: GameStatus.playing,
      players: updatedPlayers,
      currentPlayerIndex: currentPlayerIndex % updatedPlayers.length,
      direction: direction,
      drawPile: deck,
      discardPile: [firstDiscard],
      currentWildColor: wildColor,
      cardsToDraw: cardsToDraw,
      startedAt: DateTime.now(),
      houseRules: houseRules,
      scoreMode: scoreMode,
    );
  }

  GameValidationResult validatePlay(
    Game game,
    String playerId,
    CardModel card, {
    CardColor? selectedColor,
    String? customRule,
  }) {
    // Check if it's the player's turn
    if (game.currentPlayer.id != playerId) {
      return GameValidationResult.invalid('Not your turn');
    }
    
    // Check if game is active
    if (game.status != GameStatus.playing) {
      return GameValidationResult.invalid('Game is not active');
    }
    
    // Check if player has the card
    final player = game.currentPlayer;
    if (!player.hand.any((c) => c.id == card.id)) {
      return GameValidationResult.invalid('You don\'t have this card');
    }
    
    // Check if card can be played
    final topCard = game.topDiscard;
    if (topCard == null) {
      return GameValidationResult.invalid('No discard pile');
    }
    
    // Check wild draw four legality
    if (card.type == CardType.wildDrawFour) {
      final hasMatchingColor = player.hand.any((c) => 
        !c.isWildCard && c.color == (game.currentWildColor ?? topCard.color)
      );
      if (hasMatchingColor) {
        return GameValidationResult.invalid(
          'Wild Draw Four can only be played when you have no matching color cards'
        );
      }
    }
    
    // Check stacking rules
    if (game.isStackingActive && game.cardsToDraw > 0) {
      if (game.houseRules.stackingEnabled) {
        // Can only stack +2 on +2 or +4 on +4
        if (!((card.type == CardType.drawTwo && topCard.type == CardType.drawTwo) ||
              (card.type == CardType.wildDrawFour && topCard.type == CardType.wildDrawFour))) {
          return GameValidationResult.invalid('Invalid stack');
        }
      } else {
        // Must draw cards before playing
        return GameValidationResult.invalid('You must draw cards first');
      }
    }
    
    // Check if card matches
    if (!card.canPlayOn(topCard, currentWildColor: game.currentWildColor)) {
      return GameValidationResult.invalid('Card cannot be played on current discard');
    }
    
    // Validate color selection for wild cards
    if (card.isWildCard && selectedColor == null && card.type != CardType.blankWild) {
      return GameValidationResult.invalid('Must select a color for wild card');
    }
    
    return GameValidationResult.valid();
  }

  Game playCard(
    Game game,
    String playerId,
    CardModel card, {
    CardColor? selectedColor,
    String? customRule,
  }) {
    final validation = validatePlay(game, playerId, card, selectedColor: selectedColor);
    if (!validation.isValid) {
      throw Exception(validation.message);
    }
    
    var updatedGame = game;
    var updatedPlayers = List<Player>.from(game.players);
    final playerIndex = updatedPlayers.indexWhere((p) => p.id == playerId);
    final player = updatedPlayers[playerIndex];
    
    // Remove card from player's hand
    final updatedHand = player.hand.where((c) => c.id != card.id).toList();
    updatedPlayers[playerIndex] = player.copyWith(
      hand: updatedHand,
      hasCalledUno: updatedHand.length == 1,
    );
    
    // Add card to discard pile
    final updatedDiscard = List<CardModel>.from(game.discardPile)..add(card);
    
    // Handle wild color
    CardColor? newWildColor;
    if (card.isWildCard && selectedColor != null) {
      newWildColor = selectedColor;
    }
    
    // Handle card effects
    int nextPlayerIndex = game.nextPlayerIndex;
    var newDirection = game.direction;
    int cardsToDraw = 0;
    bool isStacking = false;
    int skipCount = 0;
    
    switch (card.type) {
      case CardType.skip:
        skipCount = 1;
        break;
      case CardType.reverse:
        if (updatedPlayers.length == 2) {
          // In 2-player mode, reverse acts as skip
          skipCount = 1;
        } else {
          newDirection = game.isClockwise 
              ? GameDirection.counterClockwise 
              : GameDirection.clockwise;
        }
        break;
      case CardType.drawTwo:
        cardsToDraw = 2;
        if (game.houseRules.stackingEnabled && game.isStackingActive) {
          cardsToDraw = game.cardsToDraw + 2;
          isStacking = true;
        }
        skipCount = 1;
        break;
      case CardType.wildDrawFour:
        cardsToDraw = 4;
        if (game.houseRules.stackingEnabled && game.isStackingActive) {
          cardsToDraw = game.cardsToDraw + 4;
          isStacking = true;
        }
        skipCount = 1;
        break;
      case CardType.blankWild:
        // Custom rule implementation handled separately
        break;
      default:
        break;
    }
    
    // Calculate next player
    if (skipCount > 0) {
      if (newDirection == GameDirection.clockwise) {
        nextPlayerIndex = (game.currentPlayerIndex + 1 + skipCount) % updatedPlayers.length;
      } else {
        nextPlayerIndex = (game.currentPlayerIndex - 1 - skipCount + updatedPlayers.length) % updatedPlayers.length;
      }
    } else {
      if (newDirection == GameDirection.clockwise) {
        nextPlayerIndex = (game.currentPlayerIndex + 1) % updatedPlayers.length;
      } else {
        nextPlayerIndex = (game.currentPlayerIndex - 1 + updatedPlayers.length) % updatedPlayers.length;
      }
    }
    
    // Check for game end
    GameStatus newStatus = game.status;
    String? winnerId;
    DateTime? endedAt;
    Map<String, int> newScores = Map<String, int>.from(game.playerScores);
    
    if (updatedHand.isEmpty) {
      // Player won the round
      if (game.scoreMode == ScoreMode.singleRound) {
        newStatus = GameStatus.finished;
        winnerId = playerId;
        endedAt = DateTime.now();
      } else {
        // Calculate scores
        int roundScore = 0;
        for (final p in updatedPlayers) {
          for (final c in p.hand) {
            roundScore += c.pointValue;
          }
        }
        newScores[playerId] = (newScores[playerId] ?? 0) + roundScore;
        
        // Check if player reached winning score
        if (newScores[playerId]! >= game.houseRules.winningScore) {
          newStatus = GameStatus.finished;
          winnerId = playerId;
          endedAt = DateTime.now();
        }
      }
    }
    
    return game.copyWith(
      players: updatedPlayers,
      currentPlayerIndex: nextPlayerIndex,
      direction: newDirection,
      discardPile: updatedDiscard,
      currentWildColor: newWildColor,
      cardsToDraw: cardsToDraw,
      isStackingActive: isStacking,
      status: newStatus,
      winnerId: winnerId,
      endedAt: endedAt,
      playerScores: newScores,
    );
  }

  Game drawCard(Game game, String playerId) {
    if (game.currentPlayer.id != playerId) {
      throw Exception('Not your turn');
    }
    
    if (game.status != GameStatus.playing) {
      throw Exception('Game is not active');
    }
    
    var updatedGame = game;
    var updatedPlayers = List<Player>.from(game.players);
    final playerIndex = updatedPlayers.indexWhere((p) => p.id == playerId);
    final player = updatedPlayers[playerIndex];
    
    List<CardModel> updatedDrawPile = List<CardModel>.from(game.drawPile);
    List<CardModel> updatedDiscardPile = List<CardModel>.from(game.discardPile);
    
    // Handle cards to draw (from stacking or penalties)
    int cardsToTake = game.cardsToDraw > 0 ? game.cardsToDraw : 1;
    List<CardModel> drawnCards = [];
    
    for (int i = 0; i < cardsToTake; i++) {
      // Reshuffle if draw pile is empty
      if (updatedDrawPile.isEmpty) {
        if (updatedDiscardPile.length <= 1) {
          break; // No more cards available
        }
        updatedDrawPile = _deckManager.reshuffleDiscardPile(
          updatedDiscardPile, 
          updatedDiscardPile.last
        );
        updatedDiscardPile = [updatedDiscardPile.last];
      }
      
      drawnCards.add(updatedDrawPile.removeAt(0));
    }
    
    // Add cards to player's hand
    final updatedHand = List<CardModel>.from(player.hand)..addAll(drawnCards);
    updatedPlayers[playerIndex] = player.copyWith(
      hand: updatedHand,
      hasCalledUno: false,
    );
    
    // Move to next player
    final nextPlayerIndex = game.isClockwise
        ? (game.currentPlayerIndex + 1) % updatedPlayers.length
        : (game.currentPlayerIndex - 1 + updatedPlayers.length) % updatedPlayers.length;
    
    return game.copyWith(
      players: updatedPlayers,
      currentPlayerIndex: nextPlayerIndex,
      drawPile: updatedDrawPile,
      discardPile: updatedDiscardPile,
      cardsToDraw: 0,
      isStackingActive: false,
    );
  }

  Game callUno(Game game, String playerId) {
    final playerIndex = game.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) {
      throw Exception('Player not found');
    }
    
    final player = game.players[playerIndex];
    if (player.hand.length != 1) {
      throw Exception('Can only call UNO with one card left');
    }
    
    var updatedPlayers = List<Player>.from(game.players);
    updatedPlayers[playerIndex] = player.copyWith(hasCalledUno: true);
    
    return game.copyWith(players: updatedPlayers);
  }

  Game catchUnoFailure(Game game, String targetPlayerId) {
    final playerIndex = game.players.indexWhere((p) => p.id == targetPlayerId);
    if (playerIndex == -1) {
      throw Exception('Player not found');
    }
    
    final player = game.players[playerIndex];
    if (player.hand.length != 1 || player.hasCalledUno) {
      throw Exception('Player has not failed to call UNO');
    }
    
    // Penalty: draw 2 cards
    var updatedGame = game;
    List<CardModel> updatedDrawPile = List<CardModel>.from(game.drawPile);
    
    List<CardModel> drawnCards = [];
    for (int i = 0; i < 2; i++) {
      if (updatedDrawPile.isEmpty) break;
      drawnCards.add(updatedDrawPile.removeAt(0));
    }
    
    var updatedPlayers = List<Player>.from(game.players);
    updatedPlayers[playerIndex] = player.copyWith(
      hand: List<CardModel>.from(player.hand)..addAll(drawnCards),
    );
    
    return game.copyWith(
      players: updatedPlayers,
      drawPile: updatedDrawPile,
    );
  }

  Game challengeWildDrawFour(
    Game game, 
    String challengerId, 
    bool isChallenging
  ) {
    if (!game.houseRules.challengeEnabled) {
      throw Exception('Challenges are disabled');
    }
    
    // Find the last wild draw four played
    CardModel? lastWildDrawFour;
    String? playedById;
    
    for (int i = game.discardPile.length - 1; i >= 0; i--) {
      final card = game.discardPile[i];
      if (card.type == CardType.wildDrawFour) {
        lastWildDrawFour = card;
        // Determine who played it based on game state
        break;
      }
    }
    
    if (lastWildDrawFour == null) {
      throw Exception('No Wild Draw Four to challenge');
    }
    
    if (!isChallenging) {
      // Accept, draw 4
      return _applyCardPenalty(game, challengerId, 4);
    }
    
    // Challenge: check if player had matching color
    // This would require storing hand history, simplified here
    // Assume challenge is successful (penalty to player who played it)
    return _applyCardPenalty(game, playedById ?? '', 4);
  }

  Game _applyCardPenalty(Game game, String playerId, int cardCount) {
    final playerIndex = game.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return game;
    
    var updatedPlayers = List<Player>.from(game.players);
    var updatedDrawPile = List<CardModel>.from(game.drawPile);
    
    List<CardModel> drawnCards = [];
    for (int i = 0; i < cardCount; i++) {
      if (updatedDrawPile.isEmpty) break;
      drawnCards.add(updatedDrawPile.removeAt(0));
    }
    
    final player = updatedPlayers[playerIndex];
    updatedPlayers[playerIndex] = player.copyWith(
      hand: List<CardModel>.from(player.hand)..addAll(drawnCards),
    );
    
    return game.copyWith(
      players: updatedPlayers,
      drawPile: updatedDrawPile,
    );
  }

  int calculateRoundScore(List<Player> players) {
    int total = 0;
    for (final player in players) {
      for (final card in player.hand) {
        total += card.pointValue;
      }
    }
    return total;
  }
}

class GameValidationResult {
  final bool isValid;
  final String? message;

  GameValidationResult._(this.isValid, this.message);

  factory GameValidationResult.valid() => GameValidationResult._(true, null);
  factory GameValidationResult.invalid(String message) => 
      GameValidationResult._(false, message);
}

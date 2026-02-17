const { v4: uuidv4 } = require('uuid');

class GameManager {
  constructor(db, rtdb, logger) {
    this.db = db;
    this.rtdb = rtdb;
    this.logger = logger;
    this.activeGames = new Map();
    this.activeRooms = new Map();
  }

  // Card Types
  static CardType = {
    NUMBER: 'number',
    SKIP: 'skip',
    REVERSE: 'reverse',
    DRAW_TWO: 'drawTwo',
    WILD: 'wild',
    WILD_DRAW_FOUR: 'wildDrawFour',
    BLANK_WILD: 'blankWild'
  };

  static CardColor = {
    RED: 'red',
    BLUE: 'blue',
    GREEN: 'green',
    YELLOW: 'yellow',
    WILD: 'wild'
  };

  // Create full 112-card deck
  createDeck() {
    const deck = [];
    const colors = ['red', 'blue', 'green', 'yellow'];
    
    // Create colored cards
    colors.forEach(color => {
      // One zero per color
      deck.push({
        id: uuidv4(),
        color: color,
        type: 'number',
        number: 0,
        pointValue: 0
      });
      
      // Two of each number 1-9
      for (let i = 1; i <= 9; i++) {
        deck.push({ id: uuidv4(), color, type: 'number', number: i, pointValue: i });
        deck.push({ id: uuidv4(), color, type: 'number', number: i, pointValue: i });
      }
      
      // Two Skip cards
      deck.push({ id: uuidv4(), color, type: 'skip', pointValue: 20 });
      deck.push({ id: uuidv4(), color, type: 'skip', pointValue: 20 });
      
      // Two Reverse cards
      deck.push({ id: uuidv4(), color, type: 'reverse', pointValue: 20 });
      deck.push({ id: uuidv4(), color, type: 'reverse', pointValue: 20 });
      
      // Two Draw Two cards
      deck.push({ id: uuidv4(), color, type: 'drawTwo', pointValue: 20 });
      deck.push({ id: uuidv4(), color, type: 'drawTwo', pointValue: 20 });
    });
    
    // Four Wild cards
    for (let i = 0; i < 4; i++) {
      deck.push({ id: uuidv4(), color: 'wild', type: 'wild', pointValue: 50 });
    }
    
    // Four Wild Draw Four cards
    for (let i = 0; i < 4; i++) {
      deck.push({ id: uuidv4(), color: 'wild', type: 'wildDrawFour', pointValue: 50 });
    }
    
    // Four Blank Wild cards
    for (let i = 0; i < 4; i++) {
      deck.push({ id: uuidv4(), color: 'wild', type: 'blankWild', pointValue: 50 });
    }
    
    return deck;
  }

  // Shuffle deck using Fisher-Yates algorithm
  shuffleDeck(deck) {
    const shuffled = [...deck];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  }

  // Deal cards to players
  dealCards(deck, numPlayers, cardsPerPlayer) {
    const hands = Array(numPlayers).fill(null).map(() => []);
    
    for (let i = 0; i < cardsPerPlayer; i++) {
      for (let j = 0; j < numPlayers; j++) {
        if (deck.length > 0) {
          hands[j].push(deck.shift());
        }
      }
    }
    
    return { hands, remainingDeck: deck };
  }

  // Create new game
  async createGame(roomId, players, houseRules) {
    const gameId = uuidv4();
    
    // Create and shuffle deck
    let deck = this.createDeck();
    deck = this.shuffleDeck(deck);
    
    // Deal 7 cards to each player
    const { hands, remainingDeck } = this.dealCards(deck, players.length, 7);
    
    // Update players with hands
    const updatedPlayers = players.map((player, index) => ({
      ...player,
      hand: hands[index],
      hasCalledUno: false
    }));
    
    // Find first non-wild card for discard pile
    let firstDiscard;
    let discardIndex = 0;
    while (discardIndex < remainingDeck.length) {
      const card = remainingDeck[discardIndex];
      if (card.color !== 'wild') {
        firstDiscard = card;
        remainingDeck.splice(discardIndex, 1);
        break;
      }
      discardIndex++;
    }
    
    // If all remaining are wild, just use the first one
    if (!firstDiscard) {
      firstDiscard = remainingDeck.shift();
    }
    
    // Handle special first cards
    let currentPlayerIndex = 0;
    let direction = 'clockwise';
    let cardsToDraw = 0;
    
    if (firstDiscard.type === 'skip') {
      currentPlayerIndex = 1;
    } else if (firstDiscard.type === 'reverse') {
      direction = 'counterClockwise';
    } else if (firstDiscard.type === 'drawTwo') {
      cardsToDraw = 2;
    }
    
    const game = {
      id: gameId,
      status: 'playing',
      players: updatedPlayers,
      currentPlayerIndex: currentPlayerIndex % updatedPlayers.length,
      direction,
      drawPile: remainingDeck,
      discardPile: [firstDiscard],
      currentWildColor: null,
      cardsToDraw,
      isStackingActive: false,
      startedAt: new Date().toISOString(),
      houseRules: houseRules || {
        stackingEnabled: false,
        jumpInEnabled: false,
        forcePlayEnabled: true,
        winningScore: 500,
        challengeEnabled: true
      },
      scoreMode: 'cumulative',
      playerScores: {}
    };
    
    // Store in Firestore
    await this.db.collection('games').doc(gameId).set(game);
    
    // Store in Realtime Database for fast access
    await this.rtdb.ref(`games/${gameId}`).set(game);
    
    this.activeGames.set(gameId, game);
    
    return game;
  }

  // Validate card play
  validatePlay(game, playerId, card, selectedColor) {
    const playerIndex = game.players.findIndex(p => p.id === playerId);
    if (playerIndex === -1) {
      throw new Error('Player not found');
    }
    
    if (game.currentPlayerIndex !== playerIndex) {
      throw new Error('Not your turn');
    }
    
    const player = game.players[playerIndex];
    const hasCard = player.hand.some(c => c.id === card.id);
    if (!hasCard) {
      throw new Error('You do not have this card');
    }
    
    const topCard = game.discardPile[game.discardPile.length - 1];
    
    // Check wild draw four legality
    if (card.type === 'wildDrawFour') {
      const hasMatchingColor = player.hand.some(c => 
        c.color !== 'wild' && c.color === (game.currentWildColor || topCard.color)
      );
      if (hasMatchingColor) {
        throw new Error('Wild Draw Four can only be played when you have no matching color cards');
      }
    }
    
    // Check stacking rules
    if (game.isStackingActive && game.cardsToDraw > 0) {
      if (game.houseRules.stackingEnabled) {
        const validStack = (card.type === 'drawTwo' && topCard.type === 'drawTwo') ||
                          (card.type === 'wildDrawFour' && topCard.type === 'wildDrawFour');
        if (!validStack) {
          throw new Error('Invalid stack');
        }
      } else {
        throw new Error('You must draw cards first');
      }
    }
    
    // Check if card can be played
    if (card.color !== 'wild') {
      const targetColor = game.currentWildColor || topCard.color;
      if (card.color !== targetColor && 
          card.type !== topCard.type && 
          card.number !== topCard.number) {
        throw new Error('Card cannot be played on current discard');
      }
    }
    
    // Validate color selection for wild cards
    if (card.color === 'wild' && !selectedColor && card.type !== 'blankWild') {
      throw new Error('Must select a color for wild card');
    }
    
    return true;
  }

  // Play a card
  async playCard(gameId, playerId, card, selectedColor) {
    const gameRef = this.db.collection('games').doc(gameId);
    const gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) {
      throw new Error('Game not found');
    }
    
    const game = gameDoc.data();
    
    // Validate play
    this.validatePlay(game, playerId, card, selectedColor);
    
    const playerIndex = game.players.findIndex(p => p.id === playerId);
    const player = game.players[playerIndex];
    
    // Remove card from player's hand
    const updatedHand = player.hand.filter(c => c.id !== card.id);
    game.players[playerIndex] = {
      ...player,
      hand: updatedHand,
      hasCalledUno: updatedHand.length === 1
    };
    
    // Add card to discard pile
    game.discardPile.push(card);
    
    // Handle wild color
    if (card.color === 'wild' && selectedColor) {
      game.currentWildColor = selectedColor;
    }
    
    // Handle card effects
    let nextPlayerIndex;
    let skipCount = 0;
    
    switch (card.type) {
      case 'skip':
        skipCount = 1;
        break;
      case 'reverse':
        if (game.players.length === 2) {
          skipCount = 1;
        } else {
          game.direction = game.direction === 'clockwise' ? 'counterClockwise' : 'clockwise';
        }
        break;
      case 'drawTwo':
        game.cardsToDraw = game.cardsToDraw > 0 && game.houseRules.stackingEnabled
          ? game.cardsToDraw + 2
          : 2;
        game.isStackingActive = true;
        skipCount = 1;
        break;
      case 'wildDrawFour':
        game.cardsToDraw = game.cardsToDraw > 0 && game.houseRules.stackingEnabled
          ? game.cardsToDraw + 4
          : 4;
        game.isStackingActive = true;
        skipCount = 1;
        break;
      default:
        game.isStackingActive = false;
        game.cardsToDraw = 0;
    }
    
    // Calculate next player
    const direction = game.direction === 'clockwise' ? 1 : -1;
    if (skipCount > 0) {
      nextPlayerIndex = (playerIndex + (direction * (1 + skipCount)) + game.players.length) % game.players.length;
    } else {
      nextPlayerIndex = (playerIndex + direction + game.players.length) % game.players.length;
    }
    
    game.currentPlayerIndex = nextPlayerIndex;
    
    // Check for game end
    if (updatedHand.length === 0) {
      if (game.scoreMode === 'singleRound') {
        game.status = 'finished';
        game.winnerId = playerId;
        game.endedAt = new Date().toISOString();
      } else {
        // Calculate round score
        let roundScore = 0;
        game.players.forEach(p => {
          p.hand.forEach(c => {
            roundScore += c.pointValue;
          });
        });
        
        game.playerScores[playerId] = (game.playerScores[playerId] || 0) + roundScore;
        
        // Check if player reached winning score
        if (game.playerScores[playerId] >= game.houseRules.winningScore) {
          game.status = 'finished';
          game.winnerId = playerId;
          game.endedAt = new Date().toISOString();
        }
      }
    }
    
    // Update game in database
    await gameRef.update(game);
    await this.rtdb.ref(`games/${gameId}`).set(game);
    
    return game;
  }

  // Draw a card
  async drawCard(gameId, playerId) {
    const gameRef = this.db.collection('games').doc(gameId);
    const gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) {
      throw new Error('Game not found');
    }
    
    const game = gameDoc.data();
    const playerIndex = game.players.findIndex(p => p.id === playerId);
    
    if (playerIndex !== game.currentPlayerIndex) {
      throw new Error('Not your turn');
    }
    
    const player = game.players[playerIndex];
    const cardsToTake = game.cardsToDraw > 0 ? game.cardsToDraw : 1;
    const drawnCards = [];
    
    for (let i = 0; i < cardsToTake; i++) {
      if (game.drawPile.length === 0) {
        // Reshuffle discard pile
        if (game.discardPile.length <= 1) break;
        
        const topCard = game.discardPile.pop();
        game.drawPile = this.shuffleDeck(game.discardPile);
        game.discardPile = [topCard];
      }
      
      if (game.drawPile.length > 0) {
        drawnCards.push(game.drawPile.shift());
      }
    }
    
    // Add cards to player's hand
    game.players[playerIndex] = {
      ...player,
      hand: [...player.hand, ...drawnCards],
      hasCalledUno: false
    };
    
    // Move to next player
    const direction = game.direction === 'clockwise' ? 1 : -1;
    game.currentPlayerIndex = (playerIndex + direction + game.players.length) % game.players.length;
    game.cardsToDraw = 0;
    game.isStackingActive = false;
    
    // Update game
    await gameRef.update(game);
    await this.rtdb.ref(`games/${gameId}`).set(game);
    
    return game;
  }

  // Call UNO
  async callUno(gameId, playerId) {
    const gameRef = this.db.collection('games').doc(gameId);
    const gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) {
      throw new Error('Game not found');
    }
    
    const game = gameDoc.data();
    const playerIndex = game.players.findIndex(p => p.id === playerId);
    
    if (playerIndex === -1) {
      throw new Error('Player not found');
    }
    
    const player = game.players[playerIndex];
    if (player.hand.length !== 1) {
      throw new Error('Can only call UNO with one card left');
    }
    
    game.players[playerIndex] = {
      ...player,
      hasCalledUno: true
    };
    
    await gameRef.update(game);
    await this.rtdb.ref(`games/${gameId}`).set(game);
    
    return game;
  }

  // Catch UNO failure
  async catchUnoFailure(gameId, targetPlayerId) {
    const gameRef = this.db.collection('games').doc(gameId);
    const gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) {
      throw new Error('Game not found');
    }
    
    const game = gameDoc.data();
    const playerIndex = game.players.findIndex(p => p.id === targetPlayerId);
    
    if (playerIndex === -1) {
      throw new Error('Player not found');
    }
    
    const player = game.players[playerIndex];
    if (player.hand.length !== 1 || player.hasCalledUno) {
      throw new Error('Player has not failed to call UNO');
    }
    
    // Penalty: draw 2 cards
    const drawnCards = [];
    for (let i = 0; i < 2; i++) {
      if (game.drawPile.length === 0) break;
      drawnCards.push(game.drawPile.shift());
    }
    
    game.players[playerIndex] = {
      ...player,
      hand: [...player.hand, ...drawnCards]
    };
    
    await gameRef.update(game);
    await this.rtdb.ref(`games/${gameId}`).set(game);
    
    return game;
  }

  // Challenge Wild Draw Four
  async challengeWildDrawFour(gameId, challengerId, isChallenging) {
    const gameRef = this.db.collection('games').doc(gameId);
    const gameDoc = await gameRef.get();
    
    if (!gameDoc.exists) {
      throw new Error('Game not found');
    }
    
    const game = gameDoc.data();
    
    if (!game.houseRules.challengeEnabled) {
      throw new Error('Challenges are disabled');
    }
    
    // Find the last wild draw four
    let lastWildDrawFour = null;
    let playedById = null;
    
    for (let i = game.discardPile.length - 1; i >= 0; i--) {
      const card = game.discardPile[i];
      if (card.type === 'wildDrawFour') {
        lastWildDrawFour = card;
        // In a real implementation, we'd track who played each card
        break;
      }
    }
    
    if (!lastWildDrawFour) {
      throw new Error('No Wild Draw Four to challenge');
    }
    
    if (!isChallenging) {
      // Accept, challenger draws 4
      return this._applyCardPenalty(gameId, challengerId, 4);
    }
    
    // Challenge successful (simplified - would need hand history for full implementation)
    return this._applyCardPenalty(gameId, playedById || challengerId, 4);
  }

  async _applyCardPenalty(gameId, playerId, cardCount) {
    const gameRef = this.db.collection('games').doc(gameId);
    const gameDoc = await gameRef.get();
    const game = gameDoc.data();
    
    const playerIndex = game.players.findIndex(p => p.id === playerId);
    if (playerIndex === -1) return game;
    
    const player = game.players[playerIndex];
    const drawnCards = [];
    
    for (let i = 0; i < cardCount; i++) {
      if (game.drawPile.length === 0) break;
      drawnCards.push(game.drawPile.shift());
    }
    
    game.players[playerIndex] = {
      ...player,
      hand: [...player.hand, ...drawnCards]
    };
    
    await gameRef.update(game);
    await this.rtdb.ref(`games/${gameId}`).set(game);
    
    return game;
  }

  // Join room
  async joinRoom(roomId, userId, socketId) {
    const roomRef = this.db.collection('rooms').doc(roomId);
    const roomDoc = await roomRef.get();
    
    if (!roomDoc.exists) {
      throw new Error('Room not found');
    }
    
    const room = roomDoc.data();
    
    // Track socket connection
    await this.rtdb.ref(`rooms/${roomId}/connections/${userId}`).set({
      socketId,
      joinedAt: new Date().toISOString()
    });
    
    this.logger.info(`User ${userId} connected to room ${roomId}`);
  }

  // Leave room
  async leaveRoom(roomId, userId) {
    await this.rtdb.ref(`rooms/${roomId}/connections/${userId}`).remove();
    this.logger.info(`User ${userId} disconnected from room ${roomId}`);
  }

  // Handle player disconnect
  async handleDisconnect(userId) {
    // Find any games the user is in
    const gamesSnapshot = await this.db.collection('games')
      .where('status', '==', 'playing')
      .get();
    
    gamesSnapshot.forEach(async (doc) => {
      const game = doc.data();
      const playerIndex = game.players.findIndex(p => p.id === userId);
      
      if (playerIndex !== -1) {
        // Mark player as offline
        game.players[playerIndex] = {
          ...game.players[playerIndex],
          isOnline: false,
          lastActive: new Date().toISOString()
        };
        
        await doc.ref.update({ players: game.players });
        await this.rtdb.ref(`games/${doc.id}`).update({ players: game.players });
        
        this.logger.info(`Player ${userId} marked offline in game ${doc.id}`);
      }
    });
  }

  // Get public rooms
  async getPublicRooms() {
    const snapshot = await this.db.collection('rooms')
      .where('type', '==', 'public')
      .where('status', '==', 'waiting')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();
    
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  }
}

module.exports = GameManager;

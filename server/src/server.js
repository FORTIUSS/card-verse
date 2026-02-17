require('dotenv').config();

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const admin = require('firebase-admin');
const winston = require('winston');

const GameManager = require('./game/GameManager');
const authMiddleware = require('./middleware/auth');

// Configure logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

// Initialize Firebase Admin
const serviceAccount = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: process.env.FIREBASE_DATABASE_URL,
});

const db = admin.firestore();
const rtdb = admin.database();

// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.CLIENT_URL || "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Game manager instance
const gameManager = new GameManager(db, rtdb, logger);

// Socket.IO authentication middleware
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    if (!token) {
      return next(new Error('Authentication required'));
    }
    
    const decodedToken = await admin.auth().verifyIdToken(token);
    socket.userId = decodedToken.uid;
    socket.user = decodedToken;
    next();
  } catch (error) {
    logger.error('Socket authentication failed:', error);
    next(new Error('Authentication failed'));
  }
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  logger.info(`User connected: ${socket.userId}`);
  
  // Update user online status
  rtdb.ref(`connections/${socket.userId}`).set({
    status: 'online',
    lastSeen: admin.database.ServerValue.TIMESTAMP,
    socketId: socket.id
  });

  // Join room
  socket.on('join_room', async (roomId) => {
    try {
      await gameManager.joinRoom(roomId, socket.userId, socket.id);
      socket.join(roomId);
      socket.to(roomId).emit('player_joined', { userId: socket.userId });
      logger.info(`User ${socket.userId} joined room ${roomId}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Leave room
  socket.on('leave_room', async (roomId) => {
    try {
      await gameManager.leaveRoom(roomId, socket.userId);
      socket.leave(roomId);
      socket.to(roomId).emit('player_left', { userId: socket.userId });
      logger.info(`User ${socket.userId} left room ${roomId}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Play card
  socket.on('play_card', async (data) => {
    try {
      const { gameId, card, selectedColor } = data;
      const result = await gameManager.playCard(
        gameId, 
        socket.userId, 
        card, 
        selectedColor
      );
      
      io.to(gameId).emit('game_update', result);
      logger.info(`Card played in game ${gameId} by ${socket.userId}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Draw card
  socket.on('draw_card', async (data) => {
    try {
      const { gameId } = data;
      const result = await gameManager.drawCard(gameId, socket.userId);
      
      io.to(gameId).emit('game_update', result);
      logger.info(`Card drawn in game ${gameId} by ${socket.userId}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Call UNO
  socket.on('call_uno', async (data) => {
    try {
      const { gameId } = data;
      const result = await gameManager.callUno(gameId, socket.userId);
      
      io.to(gameId).emit('game_update', result);
      io.to(gameId).emit('uno_called', { userId: socket.userId });
      logger.info(`UNO called in game ${gameId} by ${socket.userId}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Catch UNO failure
  socket.on('catch_uno', async (data) => {
    try {
      const { gameId, targetPlayerId } = data;
      const result = await gameManager.catchUnoFailure(gameId, targetPlayerId);
      
      io.to(gameId).emit('game_update', result);
      io.to(gameId).emit('uno_caught', { 
        catcherId: socket.userId, 
        targetId: targetPlayerId 
      });
      logger.info(`UNO caught in game ${gameId}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Challenge Wild Draw Four
  socket.on('challenge_wild', async (data) => {
    try {
      const { gameId, isChallenging } = data;
      const result = await gameManager.challengeWildDrawFour(
        gameId, 
        socket.userId, 
        isChallenging
      );
      
      io.to(gameId).emit('game_update', result);
      io.to(gameId).emit('challenge_made', { 
        challengerId: socket.userId, 
        isChallenging 
      });
      logger.info(`Challenge made in game ${gameId}`);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  });

  // Handle disconnect
  socket.on('disconnect', async () => {
    logger.info(`User disconnected: ${socket.userId}`);
    
    // Update user status
    rtdb.ref(`connections/${socket.userId}`).update({
      status: 'offline',
      lastSeen: admin.database.ServerValue.TIMESTAMP
    });

    // Handle disconnect in any active games
    await gameManager.handleDisconnect(socket.userId);
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Get public rooms
app.get('/api/rooms/public', async (req, res) => {
  try {
    const rooms = await gameManager.getPublicRooms();
    res.json(rooms);
  } catch (error) {
    logger.error('Error fetching public rooms:', error);
    res.status(500).json({ error: 'Failed to fetch rooms' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
});

module.exports = { app, server, io };

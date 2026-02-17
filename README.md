# CardVerses

A production-ready UNO-style multiplayer card game built with Flutter and Firebase. Play with friends online in real-time with full rule enforcement, matchmaking, and customizable house rules.

## Features

### Core Gameplay
- **112-Card Deck**: 4 colors (Red, Blue, Green, Yellow) with numbers 0-9, Skip, Reverse, Draw Two, Wild, Wild Draw Four, and 4 customizable blank wild cards
- **2-10 Players**: Support for small casual games up to large party sessions
- **Full UNO Rules**: Complete rule implementation including UNO call penalties, challenge system, and action card effects
- **Server-Side Validation**: All game logic validated on the server to prevent cheating
- **Scoring System**: Number cards (face value), Action cards (20 pts), Wild cards (50 pts)
- **Multiple Game Modes**: Single-round and cumulative scoring modes

### Multiplayer Features
- **Public Matchmaking**: Quick join public games
- **Private Rooms**: Create rooms with 6-digit codes or invite links
- **Real-Time Sync**: WebSocket-based low-latency gameplay
- **Host Migration**: Automatic host transfer if original host disconnects
- **Reconnection Handling**: Resume games after connection drops
- **Spectator Mode**: Watch ongoing games

### House Rules (Configurable)
- **Stacking**: +2 on +2, +4 on +4
- **Jump-In**: Play identical cards instantly out of turn
- **Force Play**: Must play if possible
- **Challenge System**: Challenge illegal Wild Draw Four plays
- **Custom Rules**: Define rules for blank wild cards

### User Experience
- **Authentication**: Google Sign-In, Apple Sign-In, Guest login
- **Player Profiles**: Avatars, stats, match history
- **Friends System**: Add friends and invite to games
- **Mobile-Optimized UI**: Drag or tap to play, smooth animations
- **Sound Effects & Haptics**: Immersive gameplay feedback
- **Responsive Design**: Works on phones and tablets

## Architecture

The project follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── core/                    # Core utilities, themes, constants
├── data/                    # Data layer (datasources, models, repositories)
├── domain/                  # Domain layer (entities, usecases, repositories)
├── presentation/            # Presentation layer (blocs, pages, widgets)
└── di/                      # Dependency injection
```

### Key Components

1. **Deck Manager**: Handles card creation, shuffling, and dealing
2. **Game Engine**: Validates moves, enforces rules, manages game state
3. **Multiplayer Service**: Firebase + WebSocket integration for real-time sync
4. **Auth Service**: Firebase Authentication with multiple providers

## Tech Stack

### Frontend
- **Flutter 3.x**: Cross-platform mobile framework
- **Dart**: Programming language
- **Bloc Pattern**: State management
- **Firebase SDK**: Authentication, Firestore, Realtime Database

### Backend
- **Firebase Firestore**: Game state persistence
- **Firebase Realtime Database**: Low-latency game updates
- **Firebase Authentication**: User management
- **Node.js + Socket.io**: WebSocket server for real-time gameplay
- **Cloud Functions**: Server-side game validation

## Prerequisites

- Flutter SDK >=3.0.0
- Firebase project
- Node.js >=16 (for backend server)
- Android Studio / Xcode (for mobile builds)

## Setup Instructions

### 1. Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project named "CardVerses"
3. Enable the following services:
   - **Authentication**: Enable Google and Apple sign-in providers
   - **Firestore**: Create database in locked mode
   - **Realtime Database**: Create database
   - **Storage**: Enable for avatar uploads

4. Add Android and iOS apps to your Firebase project
5. Download configuration files:
   - Android: `google-services.json` → place in `android/app/`
   - iOS: `GoogleService-Info.plist` → place in `ios/Runner/`

### 2. Flutter Configuration

```bash
# Clone the repository
git clone https://github.com/yourusername/cardverses.git
cd cardverses

# Install dependencies
flutter pub get

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Backend Server Setup

```bash
# Navigate to server directory
cd server

# Install dependencies
npm install

# Create .env file
cp .env.example .env

# Edit .env with your Firebase credentials
# FIREBASE_PROJECT_ID=your-project-id
# FIREBASE_PRIVATE_KEY=your-private-key
# FIREBASE_CLIENT_EMAIL=your-client-email

# Start the server
npm start
```

### 4. Running the App

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Release builds
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android App Bundle
flutter build ios --release          # iOS
```

## Database Schema

### Firestore Collections

```
rooms/{roomId}
  - id: string
  - code: string
  - name: string
  - type: "public" | "private"
  - status: "waiting" | "playing" | "finished" | "closed"
  - host: Player
  - players: Player[]
  - maxPlayers: number
  - houseRules: HouseRules
  - createdAt: timestamp
  - gameId: string?

games/{gameId}
  - id: string
  - status: "waiting" | "playing" | "paused" | "finished"
  - players: Player[]
  - currentPlayerIndex: number
  - direction: "clockwise" | "counterClockwise"
  - drawPile: Card[]
  - discardPile: Card[]
  - currentWildColor: Color?
  - cardsToDraw: number
  - isStackingActive: boolean
  - startedAt: timestamp
  - endedAt: timestamp?
  - winnerId: string?
  - houseRules: HouseRules
  - playerScores: Map<string, number>

users/{userId}
  - id: string
  - name: string
  - email: string?
  - avatarUrl: string?
  - stats: UserStats
  - friends: string[]
  - createdAt: timestamp
```

### Realtime Database Structure

```
rooms/
  {roomId}: Room (synced with Firestore)

games/
  {gameId}: Game (synced with Firestore)
  
connections/
  {userId}: {
    status: "online" | "offline"
    lastSeen: timestamp
    currentGame: string?
  }
```

## Security Rules

### Firestore Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Rooms: public read, authenticated write
    match /rooms/{roomId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.host.id == request.auth.uid || 
         request.resource.data.players.hasAny([request.auth.uid]));
      allow delete: if request.auth != null && resource.data.host.id == request.auth.uid;
    }
    
    // Games: only players can read/write
    match /games/{gameId} {
      allow read, write: if request.auth != null && 
        resource.data.players.hasAny([request.auth.uid]);
    }
  }
}
```

### Realtime Database Rules

```json
{
  "rules": {
    "rooms": {
      "$roomId": {
        ".read": "auth != null",
        ".write": "auth != null && (
          root.child('rooms').child($roomId).child('host').child('id').val() == auth.uid ||
          root.child('rooms').child($roomId).child('players').child(auth.uid).exists()
        )"
      }
    },
    "games": {
      "$gameId": {
        ".read": "auth != null && root.child('games').child($gameId).child('players').child(auth.uid).exists()",
        ".write": "auth != null && root.child('games').child($gameId).child('players').child(auth.uid).exists()"
      }
    }
  }
}
```

## API Documentation

### Multiplayer Service API

```dart
// Create a room
Future<Room> createRoom({
  required Player host,
  required String name,
  RoomType type = RoomType.public,
  int maxPlayers = 10,
  HouseRules? houseRules,
})

// Join a room by code
Future<Room> joinRoom(String code, Player player)

// Leave a room
Future<void> leaveRoom(String roomId, String playerId)

// Start the game
Future<Game> startGame(String roomId)

// Play a card
Future<Game> playCard({
  required String gameId,
  required String playerId,
  required CardModel card,
  CardColor? selectedColor,
})

// Draw a card
Future<Game> drawCard(String gameId, String playerId)

// Call UNO
Future<Game> callUno(String gameId, String playerId)

// Catch UNO failure
Future<Game> catchUnoFailure(String gameId, String targetPlayerId)

// Challenge Wild Draw Four
Future<Game> challengeWildDrawFour(
  String gameId, 
  String challengerId, 
  bool isChallenging
)

// Listen to room updates
Stream<Room> listenToRoom(String roomId)

// Listen to game updates
Stream<Game> listenToGame(String gameId)

// Get public rooms
Future<List<Room>> getPublicRooms()
```

## Deployment

### Mobile Apps

#### Android
1. Build release APK: `flutter build apk --release`
2. Or build App Bundle: `flutter build appbundle --release`
3. Upload to Google Play Console

#### iOS
1. Build release: `flutter build ios --release`
2. Open Xcode: `open ios/Runner.xcworkspace`
3. Archive and distribute via App Store Connect

### Backend Server

#### Deploy to Firebase Functions
```bash
cd server
firebase deploy --only functions
```

#### Deploy to Heroku
```bash
cd server
git init
git add .
git commit -m "Initial commit"
heroku create cardverses-server
git push heroku main
```

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by the classic UNO card game
- Built with Flutter and Firebase
- Thanks to all contributors

## Support

For support, email support@cardverses.com or join our Discord community.

---

Built with ❤️ by the CardVerses Team
#   c a r d - v e r s e  
 
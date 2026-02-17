import 'package:cardverses/core/theme/app_theme.dart';
import 'package:cardverses/domain/entities/card_entity.dart';
import 'package:cardverses/domain/entities/game_entity.dart';
import 'package:cardverses/domain/entities/player_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GamePage extends StatefulWidget {
  final Game game;
  final String currentPlayerId;

  const GamePage({
    super.key,
    required this.game,
    required this.currentPlayerId,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  late AnimationController _cardAnimationController;
  bool _showUnoButton = false;
  CardColor? _selectedColor;

  @override
  void initState() {
    super.initState();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  Player get currentPlayer {
    return widget.game.players.firstWhere(
      (p) => p.id == widget.currentPlayerId,
      orElse: () => widget.game.players.first,
    );
  }

  bool get isCurrentPlayerTurn => widget.game.currentPlayer.id == widget.currentPlayerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D4A1C), // Green felt table
      body: SafeArea(
        child: Stack(
          children: [
            // Background pattern
            _buildBackground(),
            
            Column(
              children: [
                // Top bar with game info
                _buildTopBar(),
                
                // Other players
                _buildOpponentsRow(),
                
                const Spacer(),
                
                // Game board (discard pile and draw pile)
                _buildGameBoard(),
                
                const Spacer(),
                
                // Current player's hand
                _buildPlayerHand(),
                
                // Action buttons
                _buildActionButtons(),
              ],
            ),
            
            // UNO button overlay
            if (_showUnoButton) _buildUnoButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF0D5A24),
            Color(0xFF0D4A1C),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _showLeaveGameDialog(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Column(
            children: [
              Text(
                'Round Score: ${widget.game.playerScores[widget.currentPlayerId] ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    widget.game.isClockwise 
                        ? Icons.rotate_right 
                        : Icons.rotate_left,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.game.isClockwise ? 'Clockwise' : 'Counter',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showGameMenu(),
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentsRow() {
    final opponents = widget.game.players
        .where((p) => p.id != widget.currentPlayerId)
        .toList();

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: opponents.length,
        itemBuilder: (context, index) {
          final player = opponents[index];
          final isCurrentTurn = widget.game.currentPlayer.id == player.id;
          
          return Container(
            width: 80,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isCurrentTurn
                        ? Border.all(color: Colors.yellow, width: 3)
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: isCurrentTurn ? Colors.yellow : Colors.grey[700],
                    child: Text(
                      player.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: isCurrentTurn ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${player.hand.length} cards',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameBoard() {
    final topCard = widget.game.topDiscard;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Draw pile
        GestureDetector(
          onTap: isCurrentPlayerTurn ? _onDrawCard : null,
          child: Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.style,
                size: 40,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 40),
        
        // Discard pile
        if (topCard != null)
          _buildCardWidget(topCard, size: 100)
        else
          Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerHand() {
    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: currentPlayer.hand.isEmpty
          ? const Center(
              child: Text(
                'No cards',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: currentPlayer.hand.length,
              itemBuilder: (context, index) {
                final card = currentPlayer.hand[index];
                final canPlay = isCurrentPlayerTurn && 
                    card.canPlayOn(
                      widget.game.topDiscard!,
                      currentWildColor: widget.game.currentWildColor,
                    );
                
                return GestureDetector(
                  onTap: canPlay ? () => _onPlayCard(card) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    transform: Matrix4.identity()
                      ..translate(0.0, canPlay ? -10.0 : 0.0),
                    child: _buildCardWidget(
                      card,
                      size: 90,
                      isPlayable: canPlay,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCardWidget(CardModel card, {required double size, bool isPlayable = false}) {
    Color cardColor;
    switch (card.color) {
      case CardColor.red:
        cardColor = AppTheme.redCard;
        break;
      case CardColor.blue:
        cardColor = AppTheme.blueCard;
        break;
      case CardColor.green:
        cardColor = AppTheme.greenCard;
        break;
      case CardColor.yellow:
        cardColor = AppTheme.yellowCard;
        break;
      case CardColor.wild:
        cardColor = AppTheme.wildCard;
        break;
    }

    String cardText;
    switch (card.type) {
      case CardType.number:
        cardText = card.number?.toString() ?? '';
        break;
      case CardType.skip:
        cardText = '⊘';
        break;
      case CardType.reverse:
        cardText = '⇄';
        break;
      case CardType.drawTwo:
        cardText = '+2';
        break;
      case CardType.wild:
        cardText = 'W';
        break;
      case CardType.wildDrawFour:
        cardText = '+4';
        break;
      case CardType.blankWild:
        cardText = '★';
        break;
    }

    return Container(
      width: size * 0.67,
      height: size,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(size * 0.1),
        boxShadow: [
          BoxShadow(
            color: isPlayable ? Colors.yellow.withOpacity(0.8) : Colors.black.withOpacity(0.3),
            blurRadius: isPlayable ? 15 : 5,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isPlayable ? Colors.yellow : Colors.white.withOpacity(0.3),
          width: isPlayable ? 3 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cardText,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          if (card.isWildCard && widget.game.currentWildColor != null && card == widget.game.topDiscard)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: size * 0.2,
              height: size * 0.2,
              decoration: BoxDecoration(
                color: _getColorFromEnum(widget.game.currentWildColor!),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
        ],
      ),
    );
  }

  Color _getColorFromEnum(CardColor color) {
    switch (color) {
      case CardColor.red:
        return AppTheme.redCard;
      case CardColor.blue:
        return AppTheme.blueCard;
      case CardColor.green:
        return AppTheme.greenCard;
      case CardColor.yellow:
        return AppTheme.yellowCard;
      case CardColor.wild:
        return AppTheme.wildCard;
    }
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            label: 'UNO!',
            color: Colors.yellow,
            onPressed: currentPlayer.hand.length == 1 ? _onCallUno : null,
          ),
          _buildActionButton(
            label: 'Challenge',
            color: Colors.orange,
            onPressed: _canChallenge() ? _onChallenge : null,
          ),
          _buildActionButton(
            label: 'Draw',
            color: Colors.blue,
            onPressed: isCurrentPlayerTurn ? _onDrawCard : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed?.call();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? color : Colors.grey[700],
        foregroundColor: isEnabled ? Colors.black : Colors.grey[500],
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isEnabled ? 4 : 0,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildUnoButton() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: _onCallUno,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.yellow, Colors.orange],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Text(
            'UNO!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  bool _canChallenge() {
    final topCard = widget.game.topDiscard;
    return topCard?.type == CardType.wildDrawFour && 
           widget.game.houseRules.challengeEnabled;
  }

  void _onPlayCard(CardModel card) {
    if (card.isWildCard && card.type != CardType.blankWild) {
      _showColorPicker(card);
    } else {
      // TODO: Call game engine to play card
      setState(() {
        _showUnoButton = currentPlayer.hand.length == 2;
      });
    }
  }

  void _showColorPicker(CardModel card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose a Color',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildColorOption(CardColor.red, AppTheme.redCard),
                    _buildColorOption(CardColor.blue, AppTheme.blueCard),
                    _buildColorOption(CardColor.green, AppTheme.greenCard),
                    _buildColorOption(CardColor.yellow, AppTheme.yellowCard),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorOption(CardColor color, Color displayColor) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedColor = color;
        });
        // TODO: Play card with selected color
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: displayColor.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _onDrawCard() {
    // TODO: Call game engine to draw card
    HapticFeedback.mediumImpact();
  }

  void _onCallUno() {
    // TODO: Call game engine to call UNO
    setState(() {
      _showUnoButton = false;
    });
    HapticFeedback.heavyImpact();
  }

  void _onChallenge() {
    // TODO: Show challenge dialog
    HapticFeedback.heavyImpact();
  }

  void _showLeaveGameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Leave Game?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave? You will forfeit the game.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showGameMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.rule, color: Colors.white),
                title: const Text('Rules', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Show rules
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('Settings', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Show settings
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Leave Game', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showLeaveGameDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

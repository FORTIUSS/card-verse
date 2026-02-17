import 'dart:math';
import 'package:cardverses/domain/entities/card_entity.dart';
import 'package:uuid/uuid.dart';

class DeckManager {
  static const int _cardsPerColor = 25;
  static const int _wildCards = 8;
  static const int _blankWildCards = 4;
  
  final _uuid = const Uuid();
  final _random = Random();

  List<CardModel> createFullDeck() {
    final deck = <CardModel>[];
    
    // Create colored cards for each color
    for (final color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
      deck.addAll(_createColorCards(color));
    }
    
    // Create wild cards
    deck.addAll(_createWildCards());
    
    // Create blank wild cards
    deck.addAll(_createBlankWildCards());
    
    return deck;
  }

  List<CardModel> _createColorCards(CardColor color) {
    final cards = <CardModel>[];
    
    // One zero per color
    cards.add(_createCard(color, CardType.number, number: 0));
    
    // Two of each number 1-9
    for (int i = 1; i <= 9; i++) {
      cards.add(_createCard(color, CardType.number, number: i));
      cards.add(_createCard(color, CardType.number, number: i));
    }
    
    // Two Skip cards
    cards.add(_createCard(color, CardType.skip));
    cards.add(_createCard(color, CardType.skip));
    
    // Two Reverse cards
    cards.add(_createCard(color, CardType.reverse));
    cards.add(_createCard(color, CardType.reverse));
    
    // Two Draw Two cards
    cards.add(_createCard(color, CardType.drawTwo));
    cards.add(_createCard(color, CardType.drawTwo));
    
    return cards;
  }

  List<CardModel> _createWildCards() {
    final cards = <CardModel>[];
    
    // Four regular Wild cards
    for (int i = 0; i < 4; i++) {
      cards.add(_createCard(CardColor.wild, CardType.wild));
    }
    
    // Four Wild Draw Four cards
    for (int i = 0; i < 4; i++) {
      cards.add(_createCard(CardColor.wild, CardType.wildDrawFour));
    }
    
    return cards;
  }

  List<CardModel> _createBlankWildCards() {
    final cards = <CardModel>[];
    
    // Four blank customizable wild cards
    for (int i = 0; i < 4; i++) {
      cards.add(_createCard(CardColor.wild, CardType.blankWild));
    }
    
    return cards;
  }

  CardModel _createCard(CardColor color, CardType type, {int? number}) {
    return CardModel(
      id: _uuid.v4(),
      color: color,
      type: type,
      number: number,
      imageUrl: _generateCardImageUrl(color, type, number),
    );
  }

  String _generateCardImageUrl(CardColor color, CardType type, int? number) {
    // Generate asset path for card image
    if (type == CardType.number) {
      return 'assets/images/cards/${color.name}_$number.png';
    }
    return 'assets/images/cards/${color.name}_${type.name}.png';
  }

  List<CardModel> shuffle(List<CardModel> deck) {
    final shuffled = List<CardModel>.from(deck);
    
    // Fisher-Yates shuffle algorithm
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    
    return shuffled;
  }

  List<List<CardModel>> dealCards(List<CardModel> deck, int numPlayers, int cardsPerPlayer) {
    if (deck.length < numPlayers * cardsPerPlayer) {
      throw Exception('Not enough cards in deck');
    }
    
    final hands = List<List<CardModel>>.generate(numPlayers, (_) => []);
    
    for (int i = 0; i < cardsPerPlayer; i++) {
      for (int j = 0; j < numPlayers; j++) {
        hands[j].add(deck.removeAt(0));
      }
    }
    
    return hands;
  }

  List<CardModel> reshuffleDiscardPile(List<CardModel> discardPile, CardModel topCard) {
    // Keep the top card, reshuffle the rest
    final cardsToReshuffle = discardPile.sublist(0, discardPile.length - 1);
    return shuffle(cardsToReshuffle);
  }
}

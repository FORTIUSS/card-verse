import 'package:equatable/equatable.dart';

enum CardColor { red, blue, green, yellow, wild }

enum CardType {
  number,
  skip,
  reverse,
  drawTwo,
  wild,
  wildDrawFour,
  blankWild,
}

class CardModel extends Equatable {
  final String id;
  final CardColor color;
  final CardType type;
  final int? number;
  final String? customRule;
  final String imageUrl;

  const CardModel({
    required this.id,
    required this.color,
    required this.type,
    this.number,
    this.customRule,
    required this.imageUrl,
  });

  bool get isActionCard =>
      type == CardType.skip ||
      type == CardType.reverse ||
      type == CardType.drawTwo;

  bool get isWildCard =>
      type == CardType.wild ||
      type == CardType.wildDrawFour ||
      type == CardType.blankWild;

  bool get isNumberCard => type == CardType.number;

  int get pointValue {
    switch (type) {
      case CardType.number:
        return number ?? 0;
      case CardType.skip:
      case CardType.reverse:
      case CardType.drawTwo:
        return 20;
      case CardType.wild:
      case CardType.wildDrawFour:
      case CardType.blankWild:
        return 50;
    }
  }

  bool canPlayOn(CardModel other, {CardColor? currentWildColor}) {
    if (isWildCard) return true;
    
    if (currentWildColor != null) {
      return color == currentWildColor;
    }
    
    return color == other.color ||
        (type == other.type && type != CardType.number) ||
        (number != null && number == other.number);
  }

  CardModel copyWith({
    String? id,
    CardColor? color,
    CardType? type,
    int? number,
    String? customRule,
    String? imageUrl,
  }) {
    return CardModel(
      id: id ?? this.id,
      color: color ?? this.color,
      type: type ?? this.type,
      number: number ?? this.number,
      customRule: customRule ?? this.customRule,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color.name,
      'type': type.name,
      'number': number,
      'customRule': customRule,
      'imageUrl': imageUrl,
    };
  }

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String,
      color: CardColor.values.byName(json['color'] as String),
      type: CardType.values.byName(json['type'] as String),
      number: json['number'] as int?,
      customRule: json['customRule'] as String?,
      imageUrl: json['imageUrl'] as String,
    );
  }

  @override
  List<Object?> get props => [id, color, type, number, customRule];
}

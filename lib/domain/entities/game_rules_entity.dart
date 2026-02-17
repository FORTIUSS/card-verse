import 'package:equatable/equatable.dart';

enum GameStatus {
  waiting,
  starting,
  playing,
  paused,
  finished,
}

enum GameDirection {
  clockwise,
  counterClockwise,
}

enum ScoreMode {
  singleRound,
  cumulative,
}

class HouseRules extends Equatable {
  final bool stackingEnabled;
  final bool jumpInEnabled;
  final bool forcePlayEnabled;
  final int winningScore;
  final bool challengeEnabled;

  const HouseRules({
    this.stackingEnabled = false,
    this.jumpInEnabled = false,
    this.forcePlayEnabled = true,
    this.winningScore = 500,
    this.challengeEnabled = true,
  });

  HouseRules copyWith({
    bool? stackingEnabled,
    bool? jumpInEnabled,
    bool? forcePlayEnabled,
    int? winningScore,
    bool? challengeEnabled,
  }) {
    return HouseRules(
      stackingEnabled: stackingEnabled ?? this.stackingEnabled,
      jumpInEnabled: jumpInEnabled ?? this.jumpInEnabled,
      forcePlayEnabled: forcePlayEnabled ?? this.forcePlayEnabled,
      winningScore: winningScore ?? this.winningScore,
      challengeEnabled: challengeEnabled ?? this.challengeEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stackingEnabled': stackingEnabled,
      'jumpInEnabled': jumpInEnabled,
      'forcePlayEnabled': forcePlayEnabled,
      'winningScore': winningScore,
      'challengeEnabled': challengeEnabled,
    };
  }

  factory HouseRules.fromJson(Map<String, dynamic> json) {
    return HouseRules(
      stackingEnabled: json['stackingEnabled'] as bool,
      jumpInEnabled: json['jumpInEnabled'] as bool,
      forcePlayEnabled: json['forcePlayEnabled'] as bool,
      winningScore: json['winningScore'] as int,
      challengeEnabled: json['challengeEnabled'] as bool,
    );
  }

  @override
  List<Object?> get props => [
        stackingEnabled,
        jumpInEnabled,
        forcePlayEnabled,
        winningScore,
        challengeEnabled,
      ];
}

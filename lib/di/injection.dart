import 'package:cardverses/data/datasources/auth_service.dart';
import 'package:cardverses/data/datasources/multiplayer_service.dart';
import 'package:cardverses/domain/usecases/deck_manager.dart';
import 'package:cardverses/domain/usecases/game_engine.dart';
import 'package:get_it/get_it.dart';

final GetIt getIt = GetIt.instance;

Future<void> init() async {
  // Services
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  
  getIt.registerLazySingleton<DeckManager>(() => DeckManager());
  
  getIt.registerLazySingleton<GameEngine>(
    () => GameEngine(getIt<DeckManager>()),
  );
  
  getIt.registerLazySingleton<MultiplayerService>(
    () => MultiplayerService(
      gameEngine: getIt<GameEngine>(),
      deckManager: getIt<DeckManager>(),
    ),
  );
}

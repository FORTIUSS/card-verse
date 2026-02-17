import 'dart:async';

import 'package:cardverses/data/datasources/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInWithGoogle>(_onSignInWithGoogle);
    on<AuthSignInWithApple>(_onSignInWithApple);
    on<AuthSignInAsGuest>(_onSignInAsGuest);
    on<AuthSignOut>(_onSignOut);
    on<AuthUserChanged>(_onUserChanged);

    _authStateSubscription = _authService.authStateChanges.listen((user) {
      add(AuthUserChanged(user));
    });
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final user = _authService.currentUser;
    if (user != null) {
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInWithGoogle(
    AuthSignInWithGoogle event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await _authService.signInWithGoogle();
      emit(Authenticated(credential.user!));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithApple(
    AuthSignInWithApple event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await _authService.signInWithApple();
      emit(Authenticated(credential.user!));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInAsGuest(
    AuthSignInAsGuest event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await _authService.signInAsGuest();
      emit(Authenticated(credential.user!));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(
    AuthSignOut event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onUserChanged(
    AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user != null) {
      emit(Authenticated(event.user!));
    } else {
      emit(Unauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}

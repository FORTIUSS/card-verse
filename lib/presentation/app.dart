import 'package:cardverses/core/theme/app_theme.dart';
import 'package:cardverses/presentation/blocs/auth/auth_bloc.dart';
import 'package:cardverses/presentation/pages/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CardVersesApp extends StatelessWidget {
  const CardVersesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
      ],
      child: MaterialApp(
        title: 'CardVerses',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const SplashPage(),
      ),
    );
  }
}

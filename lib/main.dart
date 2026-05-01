import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/library_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LibraryManagementApp());
}

class LibraryManagementApp extends StatelessWidget {
  const LibraryManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LibraryProvider>(
      create: (_) => LibraryProvider(),
      child: MaterialApp(
        title: 'Library Management System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005F73)),
          scaffoldBackgroundColor: const Color(0xFFF6F8FA),
          appBarTheme: const AppBarTheme(centerTitle: true),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

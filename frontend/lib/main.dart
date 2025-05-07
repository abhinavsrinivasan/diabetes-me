import 'package:flutter/material.dart';
import 'homescreen.dart';
import 'profilescreen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(DiabetesMeApp());

class DiabetesMeApp extends StatefulWidget {
  @override
  _DiabetesMeAppState createState() => _DiabetesMeAppState();
}

class _DiabetesMeAppState extends State<DiabetesMeApp> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    HomeScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diabetes&Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Color(0xFFFFFAF0),
        primaryColor: Color(0xFF7B4FFF),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFF1EFFF),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.black87,
                displayColor: Colors.black87,
              ),
        ),
        cardColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData.fromDefaults(
          primaryColor: Color(0xFF7B4FFF),
          secondaryColor: Color(0xFFE9DDFF),
          labelStyle: TextStyle(color: Colors.black),
        ),
        iconTheme: IconThemeData(color: Color(0xFF7B4FFF)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      themeMode: ThemeMode.light,
      home: Scaffold(
        body: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _tabs[_currentIndex],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

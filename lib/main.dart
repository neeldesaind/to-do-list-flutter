import 'package:flutter/material.dart';
import 'splash.dart';
import 'home.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo List App',
      theme: ThemeData(
        primarySwatch: Colors.blue,

      ),
      initialRoute: '/', // Set initial route to '/'
      routes: {
        '/': (context) => SplashScreen(), // Define the SplashScreen route
        '/home': (context) => TodoApp(), // Define the HomeScreen route
      },
    );
  }
}

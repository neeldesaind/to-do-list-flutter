import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Import Cupertino package

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate a long loading process
    Timer(Duration(seconds: 2), () {
      // After 3 seconds, navigate to the home screen
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/case_logo.jpg',
              width: 200,
              height: 200,
            ),
            SizedBox(height: 20),
            Text(
              'Welcome to TODO LIST APP!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 20),
            Transform.scale(
              scale: 1.5, // Increase the size by adjusting the scale factor
              child: CupertinoActivityIndicator(), // Loading indicator
            ),
          ],
        ),
      ),
    );
  }
}

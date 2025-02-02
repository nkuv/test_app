import 'package:flutter/material.dart';
import 'homepage.dart';

class SplashScreen extends StatefulWidget {
  @override
  final bool isFirstTime;  // Add this field

  // Modify the constructor to accept the 'isFirstTime' parameter
  const SplashScreen({super.key, required this.isFirstTime});

  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Delay for 3 seconds, then navigate to the main screen
    Future.delayed(Duration(seconds: 3), () {
      // Replace with the name of your main screen widget
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,  // Background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Replace with your app logo
            Image.asset(
              'assets/images/connectx_logo.png',  // Add your logo path
              height: 60,  // Adjust size as needed
            ),
            SizedBox(height: 20),  // Space between logo and text
            Text(
              'ConnectX',  // App name or any other message
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,  // Customize text color
              ),
            ),
          ],
        ),
      ),
    );
  }
}

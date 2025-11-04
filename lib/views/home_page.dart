import 'package:energy_and_power_monitor/main.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _goToPage(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyMainPage(startIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size; // screen size
    final height = size.height;
    final width = size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1976D2), // top color (logo blue)
              Colors.white, // bottom color
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( // prevents overflow on small screens
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: height * 0.1), // responsive spacing

                // Logo
                Image.asset(
                  'assets/saitech_white.png',
                  width: width * 0.9, // scale logo
                  height: height * 0.20,
                  fit: BoxFit.contain,
                ),

                SizedBox(height: height * 0.04),

                // Navigation Buttons
                _buildNavButton(
                  context,
                  "Device Management",
                  "Select Device",
                  Icons.devices,
                  0,
                  height,
                  width,
                ),
                _buildNavButton(
                  context,
                  "All Variables",
                  "Choose variables to display",
                  Icons.list_alt,
                  1,
                  height,
                  width,
                ),
                _buildNavButton(
                  context,
                  "Dashboard",
                  "View parameter values",
                  Icons.dashboard,
                  2,
                  height,
                  width,
                ),
                _buildNavButton(
                  context,
                  "Reports",
                  "Generate detailed reports",
                  Icons.bar_chart,
                  3,
                  height,
                  width,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    String mainText,
    String subText,
    IconData icon,
    int index,
    double height,
    double width,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: height * 0.01,
        horizontal: width * 0.05,
      ),
      child: SizedBox(
        width: double.infinity,
        height: height * 0.1, // scale button height
        child: ElevatedButton(
          onPressed: () => _goToPage(context, index),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF5E35B1),
            padding: EdgeInsets.symmetric(horizontal: width * 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: height * 0.06, // scale icon
                color: const Color(0xFF1976D2),
              ),
              SizedBox(width: width * 0.05),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mainText,
                    style: TextStyle(
                      fontSize: height * 0.022, // responsive font size
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subText,
                    style: TextStyle(
                      fontSize: height * 0.018,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

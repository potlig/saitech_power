import 'package:energy_and_power_monitor/main.dart';
import 'package:energy_and_power_monitor/widgets/Appbar.dart';
import 'package:flutter/material.dart';

class PageTemplate extends StatelessWidget {
  const PageTemplate({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: const CustomAppBar(
      //   title: "Home",
      //   showBackButton: true, // No back button for Home
      //   actions: [
      //     Padding(
      //       padding: EdgeInsets.only(right: 12.0),
      //     ),
      //   ],
      // ),
    );
  }
}

class TemplateScreen extends StatefulWidget {
  const TemplateScreen({super.key});

  @override
  State<TemplateScreen> createState() => _TemplateScreenSate();
}

class _TemplateScreenSate extends State<TemplateScreen> {
  @override
    Widget build(BuildContext context) {
      return Scaffold(

      );
    }
}
import 'package:energy_and_power_monitor/views/all_variables_page.dart';
import 'package:energy_and_power_monitor/views/dashboard_page.dart';
import 'package:energy_and_power_monitor/views/device_management_page.dart';
import 'package:energy_and_power_monitor/views/home_page.dart';
import 'package:energy_and_power_monitor/views/reports_page.dart';
import 'package:energy_and_power_monitor/widgets/Appbar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF151026);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saitech Power',
      theme: ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(), // 👈 Start with HomePage
    );
  }
}

class MyMainPage extends StatefulWidget {
  final int startIndex; // 👈 allow passing tab index
  const MyMainPage({super.key, this.startIndex = 0});

  @override
  State<MyMainPage> createState() => _MyMainPagePageState();
}

class _MyMainPagePageState extends State<MyMainPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex; // 👈 use startIndex
  }

  // List of pages for each tab
  final List<Widget> _pages = const [
    DeviceManagementPage(),
    AllVariablesPage(),
    DashboardPage(),
    ReportsPage(),
  ];

  // List of bottom navigation items
  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.devices),
      label: 'Device Mgt.',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.list_alt),
      label: 'All Variables',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart),
      label: 'Reports',
    ),
  ];

  // List of AppBar titles for each page
  final List<String> _titles = const [
    "Device Management",
    "All Variables",
    "Dashboard",
    "Reports",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hide AppBar on Home tab
      appBar: CustomAppBar(
              title: _titles[_currentIndex],
              showBackButton: false,
            ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: _navItems,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'payment_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

class MainScreen extends StatefulWidget {
  final int totalCoins;

  const MainScreen({super.key, required this.totalCoins});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  late List<Widget> screens;

  @override
  void initState() {
    super.initState();

    screens = [
      DashboardScreen(totalCoins: widget.totalCoins),

      SurveyHomePage(),

      const PaymentScreen(),

      SettingsScreen(totalCoins: widget.totalCoins),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],

      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 15, top: 10),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [

            // البيت
            GestureDetector(
              onTap: () => setState(() => currentIndex = 0),
              child: Image.asset(
                'assets/images/image_7.png',
                width: 40,
              ),
            ),

            // المهام والاستطلاع
            GestureDetector(
              onTap: () => setState(() => currentIndex = 1),
              child: Image.asset(
                'assets/images/tasks_icon.png',
                width: 40,
              ),
            ),

            // الدفع
            GestureDetector(
              onTap: () => setState(() => currentIndex = 2),
              child: Image.asset(
                'assets/images/image_8.png',
                width: 40,
              ),
            ),

            // الإعدادات
            GestureDetector(
              onTap: () => setState(() => currentIndex = 3),
              child: Image.asset(
                'assets/images/image_9.png',
                width: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
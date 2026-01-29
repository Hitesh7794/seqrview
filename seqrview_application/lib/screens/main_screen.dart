import 'package:flutter/material.dart';
import '../app/session_controller.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'duties/my_duties_screen.dart';


class MainScreen extends StatefulWidget {
  final SessionController session;
  const MainScreen({super.key, required this.session});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Theme State
  bool get _isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update); // Listen for Theme changes
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    // If not on Home tab, go back to Home
    if (_currentIndex != 0) {
      _onTabTapped(0);
      return false;
    }

    // If on Home tab, show Exit Confirmation
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF1F2937) : Colors.white,
        title: Text(
          "Exit App", 
          style: TextStyle(color: _isDark ? Colors.white : Colors.black87)
        ),
        content: Text(
          "Are you sure you want to exit?",
          style: TextStyle(color: _isDark ? Colors.grey[300] : Colors.black54)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // No
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Yes
            child: const Text("Exit", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(
              session: widget.session,
              onNavigateToTab: _onTabTapped,
            ),
            MyDutiesScreen(session: widget.session),
            ProfileScreen(session: widget.session),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: _isDark ? const Color(0xFF1F2937) : Colors.white,
          selectedItemColor: _isDark ? Colors.white : Colors.black,
          unselectedItemColor: _isDark ? Colors.grey[500] : Colors.grey[400],
          showUnselectedLabels: true,
          elevation: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Duties',
            ),
  
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}


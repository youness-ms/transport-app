import 'package:flutter/material.dart';
import 'package:transport/screens/map_screen.dart';
import 'screens/map_screen.dart';

void main() {

  runApp(const TransportApp());
}

class TransportApp extends StatelessWidget {
  const TransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transport App',
      home: MapScreen(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transport App"),
      ),
      body: const Center(
        child: Text(
          "My Transport App",
          style: TextStyle(fontSize: 25),
        ),
      ),
    );
  }
}
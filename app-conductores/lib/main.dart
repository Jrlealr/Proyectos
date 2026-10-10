import 'package:flutter/material.dart';

void main() => runApp(const AppConductores());

class AppConductores extends StatelessWidget {
  const AppConductores({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Conductores',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('App Conductores')),
      ),
    );
  }
}

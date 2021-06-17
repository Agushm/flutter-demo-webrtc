import 'package:flutter/material.dart';

class RingingCallScreen extends StatefulWidget {
  @override
  _RingingCallScreenState createState() => _RingingCallScreenState();
}

class _RingingCallScreenState extends State<RingingCallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Seseorang menelepon anda!'),
          MaterialButton(
            color: Colors.blue,
            child: Icon(Icons.call),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          MaterialButton(
            color: Colors.red,
            child: Icon(Icons.call_end),
            onPressed: () {
              Navigator.pop(context, false);
            },
          )
        ],
      ),
    );
  }
}

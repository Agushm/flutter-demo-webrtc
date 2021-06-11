import 'dart:core';


import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'src/data_channel_sample.dart';
import 'src/demo2_screen.dart';
import 'src/get_display_media_sample.dart';
import 'src/get_user_media_sample.dart'
    if (dart.library.html) 'src/get_user_media_sample_web.dart';
import 'src/loopback_sample.dart';
import 'src/route_item.dart';
import 'src/demo_screen.dart';

void main() {
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  } else if (WebRTC.platformIsAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    startForegroundService();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(MyApp());
}

Future<bool> startForegroundService() async {
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: 'Title of the notification',
    notificationText: 'Text of the notification',
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(
        name: 'background_icon',
        defType: 'drawable'), // Default is ic_launcher from folder mipmap
  );
  return FlutterBackground.initialize(androidConfig: androidConfig);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late List<RouteItem> items;

  @override
  void initState() {
    super.initState();
    _initItems();
  }

  ListBody _buildRow(context, item) {
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(item.title),
        onTap: () => item.push(context),
        trailing: Icon(Icons.arrow_right),
      ),
      Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: Text('Flutter-WebRTC example'),
          ),
          body: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(0.0),
              itemCount: items.length,
              itemBuilder: (context, i) {
                return _buildRow(context, items[i]);
              })),
    );
  }

  void _initItems() {
    items = <RouteItem>[
      RouteItem(
          title: 'GetUserMedia',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => GetUserMediaSample()));
          }),
      RouteItem(
          title: 'GetDisplayMedia',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) =>
                        GetDisplayMediaSample()));
          }),
      RouteItem(
          title: 'LoopBack Sample',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => LoopBackSample()));
          }),
      RouteItem(
          title: 'DataChannel',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => DataChannelSample()));
          }),
      RouteItem(
          title: 'Demo Screen',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => DemoScreen()));
          }),
      RouteItem(
          title: 'Demo2 Screen',
          push: (BuildContext context) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => Demo2Screen()));
          }),
    ];
  }
}
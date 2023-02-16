import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rF2 LiveTiming Tool',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: const MyHomePage(title: 'rF2 LiveTiming Tool'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  WebSocketChannel? uiChannel;
  WebSocketChannel? proxyChannel;

  final localPortController = TextEditingController(text: "5397");
  final serverNameController = TextEditingController(text: "rF2Server");
  final proxyUrlController = TextEditingController();

  String currentTrack = "";

  void _sendTrackMap() {
    http
        .get(Uri.parse(
            "http://localhost:${localPortController.text}/rest/trackmap"))
        .then((response) => {
          proxyChannel?.sink.add('{"topic": "TrackMap", "body": { "trackName": "$currentTrack", "trackMap": ${response.body} }}')
        });
  }

  void _connectToServices() {
    // create websocket channels
    uiChannel = WebSocketChannel.connect(
      Uri.parse("ws://localhost:${localPortController.text}/websocket/ui"),
    );
    proxyChannel = WebSocketChannel.connect(
      Uri.parse(
          'ws://${proxyUrlController.text}/rf2ws/${Uri.encodeComponent(serverNameController.text)}'),
    );

    // sub to required rf2 messages
    /*

      exampleSocket.send(
        JSON.stringify({
          messageType: 'SUB',
          topic: 'SessionInfo',
        })
      )
      exampleSocket.send(
        JSON.stringify({
          messageType: 'SUB',
          topic: 'LiveStandings',
        })
      )
    }
     */
    uiChannel?.sink.add('{"messageType": "SUB", "topic": "SessionInfo"}');
    uiChannel?.sink.add('{"messageType": "SUB", "topic": "LiveStandings"}');
    uiChannel?.stream.listen((message) {
      final msgJson = jsonDecode(message);
      if (msgJson["topic"] == "SessionInfo") {
        currentTrack = message["body"]["trackName"] ?? "";
      }

      proxyChannel?.sink.add(message);
    });
    proxyChannel?.stream.listen((message) {
      switch (message) {
        case "TrackMap":
          return _sendTrackMap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextField(
                controller: localPortController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'rF2 webui port:',
                  hintText: '5397',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextField(
                controller: serverNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'rF2 Server Name for the live timing site:',
                  hintText: 'rF2Server',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextField(
                controller: proxyUrlController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'domain and port for the proxy server:',
                  hintText: 'ltproxy.example.com:5398',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                      uiChannel == null
                          ? Colors.deepOrange
                          : Colors.grey.shade700),
                  foregroundColor:
                      MaterialStateProperty.all<Color>(Colors.white),
                ),
                onPressed: () {
                  if (uiChannel == null) {
                    setState(() {
                      _connectToServices();
                    });
                  }
                },
                child: const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

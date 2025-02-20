import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice-to-Action App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final SpeechToText _speechToText = SpeechToText();
  String _transcription = "";
  List<String> _tasks = [];
  bool _isListening = false;

  // Start listening to voice
  void startListening() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) => print("Speech status: $status"),
      onError: (error) => print("Speech error: $error"),
    );

    if (available) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          setState(() => _transcription = result.recognizedWords);
        },
      );
    } else {
      print("Speech recognition not available.");
    }
  }

  // Stop listening and process transcription
  void stopListening() {
    _speechToText.stop();
    setState(() => _isListening = false);

    if (_transcription.isNotEmpty) {
      print("🎤 Transcription: $_transcription");
      extractActions(_transcription);
    } else {
      print("❌ No speech detected.");
    }
  }

  // Extract actions via backend API
  Future<void> extractActions(String text) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.21.154.32:8000/extract-actions/'), // Updated IP
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _tasks = List<String>.from(data['tasks'] ?? []));

        if (_tasks.isNotEmpty) {
          for (String task in _tasks) {
            saveTaskToFirebase(task, DateTime.now().toString(), "Auto-generated");
          }
        } else {
          print("⚠️ No tasks extracted.");
        }
      } else {
        print("❌ API request failed: ${response.statusCode}");
      }
    } catch (e) {
      print("🚫 Error extracting actions: $e");
    }
  }

  // Save task to Firestore
  Future<void> saveTaskToFirebase(String task, String date, String keyPoint) async {
    try {
      DocumentReference docRef = await FirebaseFirestore.instance.collection('tasks').add({
        'task': task,
        'date': date,
        'keyPoint': keyPoint,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("✅ Task saved with ID: ${docRef.id}");
    } catch (e) {
      print("❌ Failed to save task: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice-to-Action App')),
      body: Column(
        children: [
          // Transcription display
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _transcription.isEmpty ? 'Start speaking...' : _transcription,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),

          // Task list
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.task),
                  title: Text(_tasks[index]),
                );
              },
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isListening ? null : startListening,
                  icon: const Icon(Icons.mic),
                  label: const Text('Start Listening'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isListening ? stopListening : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Listening'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatPrivatePage extends StatefulWidget {
  final String me;
  final String other;

  const ChatPrivatePage({
    super.key,
    required this.me,
    required this.other,
  });

  @override
  State<ChatPrivatePage> createState() => _ChatPrivatePageState();
}

class _ChatPrivatePageState extends State<ChatPrivatePage> {
  final TextEditingController ctrl = TextEditingController();
  final String api = "http://127.0.0.1:3000/chat/private";
  List chats = [];

  @override
  void initState() {
    super.initState();
    loadChat();
  }

  Future<void> loadChat() async {
    final res = await http.get(
      Uri.parse("$api?me=${widget.me}&with=${widget.other}"),
    );
    if (res.statusCode == 200) {
      setState(() {
        chats = jsonDecode(res.body);
      });
    }
  }

  Future<void> send() async {
    if (ctrl.text.isEmpty) return;

    await http.post(
      Uri.parse(api),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "from": widget.me,
        "to": widget.other,
        "message": ctrl.text,
      }),
    );

    ctrl.clear();
    loadChat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.other),
        backgroundColor: const Color(0xFFB71C1C),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (_, i) {
                final m = chats[i];
                final isMe = m["from"] == widget.me;

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.redAccent
                          : Colors.grey[800],
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Text(
                      m["message"],
                      style: const TextStyle(
                          color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  color: const Color(0xFF1E1E1E),
  child: Row(
    children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.redAccent,
          decoration: const InputDecoration(
            hintText: "Ketik pesan...",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.send, color: Colors.redAccent),
        onPressed: send,
      )
    ],
  ),
),
        ],
      ),
    );
  }
}
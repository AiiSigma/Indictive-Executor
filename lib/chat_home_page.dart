import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'chat_public.dart';
import 'chat_private.dart';

class ChatHomePage extends StatefulWidget {
  final String myName;
  const ChatHomePage({super.key, required this.myName});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final String api = "http://127.0.0.1:3000/chat/list";
  List chats = [];

  @override
  void initState() {
    super.initState();
    loadChats();
  }

  Future<void> loadChats() async {
    final res =
        await http.get(Uri.parse("$api?me=${widget.myName}"));
    if (res.statusCode == 200) {
      setState(() {
        chats = jsonDecode(res.body);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Chats"),
        backgroundColor: const Color(0xFFB71C1C),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search username...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (username) {
                if (username.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPrivatePage(
                      me: widget.myName,
                      other: username,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (_, i) {
                final c = chats[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(
                      c["type"] == "public"
                          ? Icons.public
                          : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(c["title"],
                      style:
                          const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    c["lastMessage"],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    if (c["type"] == "public") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPublicPage(
                            myName: widget.myName,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPrivatePage(
                            me: widget.myName,
                            other: c["with"],
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
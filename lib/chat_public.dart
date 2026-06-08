import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatPublicPage extends StatefulWidget {
  final String myName;

  const ChatPublicPage({
    super.key,
    required this.myName,
  });

  @override
  State<ChatPublicPage> createState() => _ChatPublicPageState();
}

class _ChatPublicPageState extends State<ChatPublicPage> {
  final TextEditingController _msgCtrl = TextEditingController();

  // ================= API CONFIG =================
  final String apiUrl = "http://127.0.0.1:3000/chat/public";

  List<Map<String, dynamic>> chats = [];

  // ===== RED THEME COLORS (TETAP) =====
  final Color redPrimary = const Color(0xFFE53935);
  final Color redDark = const Color(0xFFB71C1C);
  final Color bubbleOther = const Color(0xFF2B2B2B);

  @override
  void initState() {
    super.initState();
    loadChat();
  }

  // ================= LOAD CHAT =================
  Future<void> loadChat() async {
    try {
      final res = await http.get(Uri.parse(apiUrl));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          chats = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {}
  }

  // ================= SEND CHAT =================
  Future<void> sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": widget.myName,
          "message": _msgCtrl.text.trim(),
        }),
      );

      _msgCtrl.clear();
      loadChat(); // reload history
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: redDark,
        leading: const Icon(Icons.forum),
        title: const Row(
          children: [
            Icon(Icons.public, size: 18),
            SizedBox(width: 6),
            Text("Public Chat"),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.groups),
          )
        ],
      ),

      body: Column(
        children: [
          // ===== CHAT LIST (UI TETAP) =====
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final data = chats[i];
                final bool isMe = data["username"] == widget.myName;

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints:
                        const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: isMe ? redPrimary : bubbleOther,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft:
                            isMe ? const Radius.circular(14) : Radius.zero,
                        bottomRight:
                            isMe ? Radius.zero : const Radius.circular(14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                data["username"],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        Text(
                          data["message"],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ===== INPUT AREA (UI TETAP) =====
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.message, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Tulis pesan...",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.redAccent,
                    onPressed: sendMessage,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
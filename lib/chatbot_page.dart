import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ================= EXTENSION FIX =================
/// INI YANG MEMPERBAIKI ERROR takeLast
extension TakeLastExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) return List<T>.from(this);
    return sublist(length - count);
  }
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  bool isSending = false;

  // ===== COLOR SCHEME (TIDAK DIUBAH) =====
  final Color blackColor    = const Color(0xFF0A0A0A);
  final Color darkRedColor  = const Color(0xFF5A0F0F);
  final Color lightRedColor = const Color(0xFFB23A3A);
  final Color whiteColor    = const Color(0xFFE0E0E0);
  final Color greyColor     = const Color(0xFF2A2A2A);

@override
void initState() {
  super.initState();

  // FULLSCREEN (NAVBAR + STATUS BAR HILANG)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  loadChatHistory();
}

  // ================= LOAD HISTORY =================
  Future<void> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getString('ai_chat_history');
    if (history != null) {
      setState(() {
        messages = List<Map<String, dynamic>>.from(json.decode(history));
      });
    }
  }

  // ================= SAVE HISTORY =================
  Future<void> saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ai_chat_history', json.encode(messages));
  }

  // ================= SEND MESSAGE =================
  Future<void> sendMessage() async {
    if (_messageController.text.trim().isEmpty || isSending) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      messages.add({
        "role": "user",
        "content": userMessage,
        "time": DateTime.now().toIso8601String()
      });
      isSending = true;
    });

    scrollToBottom();
    saveChatHistory();

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:3000/chatbot"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "message": userMessage,
          "history": messages.takeLast(10)
        }),
      );

      final data = json.decode(response.body);

      setState(() {
        messages.add({
          "role": "ai",
          "content": data['reply'] ?? "AI tidak merespon.",
          "time": DateTime.now().toIso8601String()
        });
        isSending = false;
      });

      saveChatHistory();
      scrollToBottom();
    } catch (e) {
      setState(() {
        isSending = false;
        messages.add({
          "role": "ai",
          "content": "Gagal terhubung ke AI Server.",
          "time": DateTime.now().toIso8601String()
        });
      });
    }
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackColor,
      appBar: AppBar(
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios_new),
    onPressed: () {
      Navigator.pop(context); // ⬅ KEMBALI KE PAGE SEBELUMNYA
    },
  ),
  elevation: 0,
  backgroundColor: blackColor,
  centerTitle: true,
  title: Column(
    children: [
      Text(
        "Welcome Di Menu AI",
        style: TextStyle(
          color: lightRedColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        "Ask Anything • Fast AI Response",
        style: TextStyle(
          color: whiteColor.withOpacity(0.6),
          fontSize: 11,
        ),
      ),
    ],
  ),
),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? darkRedColor : greyColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Text(
                      msg['content'],
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (isSending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "AI sedang berpikir...",
                style: TextStyle(color: lightRedColor),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: greyColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: whiteColor),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Tanya AI apa saja...",
                      hintStyle:
                          TextStyle(color: whiteColor.withOpacity(0.4)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: lightRedColor),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
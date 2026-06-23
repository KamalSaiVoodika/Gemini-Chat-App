import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Chat Demo',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const ChatScreen(),
    );
  }
}

// Simple message model — role is either 'user' or 'model'
class ChatMessage {
  final String role;
  String text;
  bool isStreaming;

  ChatMessage({required this.role, required this.text, this.isStreaming = false});
}

/// Removes common markdown symbols (bold/italic asterisks, underscores,
/// header hashes, inline code backticks) so the model's response displays
/// as clean plain text instead of showing literal ** or # characters.
String stripMarkdown(String input) {
  return input
      .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '') // **bold**
      .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '') // *italic*
      .replaceAllMapped(RegExp(r'__(.*?)__'), (m) => m.group(1) ?? '') // __bold__
      .replaceAllMapped(RegExp(r'(?<!\w)_(.*?)_(?!\w)'), (m) => m.group(1) ?? '') // _italic_
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '') // # headers
      .replaceAllMapped(RegExp(r'`(.*?)`'), (m) => m.group(1) ?? ''); // `code`
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found. Add it to your .env file.');
    }

    // Initialize the Gemini model with a system instruction
    _model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'You are a helpful, concise assistant inside a Flutter demo app. '
        'Keep responses clear and not too long.',
      ),
      generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 1024),
    );

    // Start a chat session — this maintains conversation history automatically
    _chatSession = _model.startChat();
  }

  Future<void> _sendMessage() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: userText));
      _isSending = true;
      _controller.clear();
    });
    _scrollToBottom();

    // Add an empty model message that we'll progressively fill as chunks stream in
    final modelMessage = ChatMessage(role: 'model', text: '', isStreaming: true);
    setState(() => _messages.add(modelMessage));

    try {
      final responseStream = _chatSession.sendMessageStream(Content.text(userText));

      // Each chunk contains a piece of the response — append it as it arrives
      await for (final chunk in responseStream) {
        final chunkText = chunk.text;
        if (chunkText != null) {
          setState(() {
            modelMessage.text += chunkText;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() {
        modelMessage.text = 'Error: Failed to get response. ${e.toString()}';
      });
    } finally {
      setState(() {
        modelMessage.isStreaming = false;
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Chat Demo'), backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('Ask me anything', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _ChatBubble(message: message);
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(color: isUser ? Colors.indigo.shade600 : Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.text.isEmpty && message.isStreaming ? '...' : stripMarkdown(message.text),
                style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15),
              ),
            ),
            if (message.isStreaming && message.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
              ),
          ],
        ),
      ),
    );
  }
}

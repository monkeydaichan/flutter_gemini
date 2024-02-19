import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

final googleAIStudioAPIKey = dotenv.get('GOOGLE_AI_STUDIO_KEY');

final generativeModelProvider =
    Provider<GenerativeModel>((ref) => GenerativeModel(apiKey: googleAIStudioAPIKey, model: 'gemini-pro'));

final messagesNotifier = StateNotifierProvider<MessagesNotifier, List<types.Message>>((ref) {
  return MessagesNotifier(ref.watch(generativeModelProvider).startChat());
});

class MessagesNotifier extends StateNotifier<List<types.Message>> {
  MessagesNotifier(this.chat) : super([]);

  late final ChatSession chat;

  void addMessage(types.User author, String text) {
    final timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = types.TextMessage(author: author, id: timeStamp, text: text);
    state = [message, ...state];
  }

  Future<void> askGemini(String question) async {
    addMessage(me, question);
    final content = Content.text(question);
    try {
      final response = await chat.sendMessage(content);
      final message = response.text ?? 'Retry later...';
      addMessage(gemini, message);
    } on Exception {
      addMessage(gemini, 'Retry later...');
    }
  }
}

const gemini = types.User(id: 'gemini');
const me = types.User(id: 'user');

class ChatRoomScreen extends ConsumerWidget {
  const ChatRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesNotifier);
    return Scaffold(
      body: Chat(
        user: me,
        messages: messages,
        onSendPressed: (a) {
          ref.read(messagesNotifier.notifier).askGemini(a.text);
        },
      ),
    );
  }
}

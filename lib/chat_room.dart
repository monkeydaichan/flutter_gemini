import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

final googleAIStudioAPIKey = dotenv.get('GOOGLE_AI_STUDIO_KEY');

final generativeModelProvider =
    Provider<GenerativeModel>((ref) => GenerativeModel(apiKey: googleAIStudioAPIKey, model: 'gemini-pro'));

final messagesNotifier = StateNotifierProvider<MessagesNotifier, List<types.Message>>((ref) {
  return MessagesNotifier(ref.watch(generativeModelProvider).startChat());
});

class MessagesNotifier extends StateNotifier<List<types.Message>> {
  MessagesNotifier(this.chat) : super([]);

  late final ChatSession chat;

  Stream<GenerateContentResponse>? responseStream;

  String get messageId => const Uuid().v4();
  bool _chatting = false;

  void startChatting() {
    if (_chatting) return;

    _chatting = true;
    final id = messageId;
    responseStream?.listen(
      (GenerateContentResponse message) {
        final textMessage = message.text ?? '';
        if (state.any((m) => m.id == id)) {
          editMessage(id, textMessage);
        } else {
          addMessage(gemini, textMessage, id: id);
        }
      },
      onError: (error) {
        addMessage(gemini, 'Please try again later.');
      },
      onDone: () {
        _chatting = false;
      },
    );
  }

  String addMessage(types.User author, String text, {String? id}) {
    id = id ?? messageId;
    final message = types.TextMessage(author: author, id: id, text: text);
    state = [message, ...state];
    return id;
  }

  void editMessage(String messageId, String newText) {
    final List<types.Message> updatedMessages = state.map((message) {
      if (message.id == messageId && message is types.TextMessage) {
        return message.copyWith(text: message.text + newText);
      }
      return message;
    }).toList();

    state = updatedMessages;
  }

  Future<void> ask(String question) async {
    addMessage(me, question);
    final content = Content.text(question);
    try {
      responseStream = chat.sendMessageStream(content);
      startChatting();
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
        customMessageBuilder: (p0, {required messageWidth}) {
          return const Text('a');
        },
        messages: messages,
        onSendPressed: (a) {
          ref.read(messagesNotifier.notifier).ask(a.text);
        },
      ),
    );
  }
}

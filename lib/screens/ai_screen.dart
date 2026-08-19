import 'package:flutter/material.dart';

import '../models/ai_place.dart';
import '../services/ai_data_service.dart';
import '../services/ai_service.dart';

class AiScreen extends StatefulWidget {
  final Future<void> Function(
      double latitude,
      double longitude,
      ) onGoToPlace;

  const AiScreen({
    super.key,
    required this.onGoToPlace,
  });

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController messageController =
  TextEditingController();
  final AiDataService aiDataService =
  AiDataService();

  final AiService aiService = AiService();

  bool isSending = false;
  List<AiPlace> availablePlaces = [];
  bool isLoadingPlaces = true;
  final ScrollController scrollController =
  ScrollController();

  final List<ChatMessage> messages = [];



  final void Function(AiPlace place) onViewPlace;

  Future<void> loadAiPlaces() async {
    final places =
    await aiDataService.loadPlaces();

    if (!mounted) return;

    setState(() {
      availablePlaces = places;
      isLoadingPlaces = false;
    });
  }

  Widget _buildAiMessage(ChatMessage message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),

          if (message.place != null) ...[
            const SizedBox(height: 12),

            Text(
              message.place!.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              message.place!.category,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // We'll implement this next.
                    },
                    child: const Text(
                      'View place',
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final place = message.place;

                      if (place == null) return;

                      await widget.onGoToPlace(
                        place.latitude,
                        place.longitude,
                      );
                    },
                    child: const Text(
                      'Go there',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadAiPlaces();
  }
  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final message = messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    setState(() {
      messages.add(
        ChatMessage(
          text: message,
          isUser: true,
        ),
      );

      isSending = true;
    });

    messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final recommendation = await aiService.ask(
        message: message,
        places: availablePlaces,
      );

      if (!mounted) return;

      final place = availablePlaces.firstWhere(
            (place) => place.id == recommendation.placeId,
      );

      setState(() {
        messages.add(
          ChatMessage(
            text: recommendation.message,
            isUser: false,
            place: place,
          ),
        );

        isSending = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add(
          ChatMessage(
            text: 'Sorry, something went wrong.',
            isUser: false,
          ),
        );

        isSending = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
              child: Text(
                'Ask me about places, food, cafés, shopping, and more.',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                if (message.isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      constraints: BoxConstraints(
                        maxWidth:
                        MediaQuery.of(context).size.width * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: Alignment.centerLeft,
                  child: _buildAiMessage(message),
                );
              },
            ),
          ),
          if (isSending)
            const Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Thinking...'),
                  ],
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      textInputAction:
                      TextInputAction.send,
                      onSubmitted: (_) {
                        sendMessage();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Ask something...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: sendMessage,
                    icon: const Icon(Icons.send),
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

class ChatMessage {
  final String text;
  final bool isUser;
  final AiPlace? place;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.place,
  });
}
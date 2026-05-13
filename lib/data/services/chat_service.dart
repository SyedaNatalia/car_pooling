import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String text;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.text,
    required this.sentAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhoto: data['senderPhoto'],
      text: data['text'] ?? '',
      sentAt: data['sentAt'] != null
          ? DateTime.parse(data['sentAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
      };
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _messagesRef(String rideId) => _firestore
      .collection(AppConstants.chatsCollection)
      .doc(rideId)
      .collection('messages');

  // ─── Stream Messages ──────────────────────────────────────────────
  Stream<List<ChatMessage>> streamMessages(String rideId) {
    return _messagesRef(rideId)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessage.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }

  // ─── Send Message ─────────────────────────────────────────────────
  Future<void> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final message = ChatMessage(
      id: '',
      senderId: senderId,
      senderName: senderName,
      senderPhoto: senderPhoto,
      text: text.trim(),
      sentAt: DateTime.now(),
    );

    await _messagesRef(rideId).add(message.toMap());

    // Update last message on the chat document for previews
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(rideId)
        .set({
      'rideId': rideId,
      'lastMessage': text.trim(),
      'lastMessageAt': DateTime.now().toIso8601String(),
      'lastSenderId': senderId,
    }, SetOptions(merge: true));
  }

  // ─── Delete Message ───────────────────────────────────────────────
  Future<void> deleteMessage({
    required String rideId,
    required String messageId,
  }) async {
    await _messagesRef(rideId).doc(messageId).delete();
  }
}
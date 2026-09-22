import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/chat_models.dart';
import '../models/professional_profile_model.dart';
import '../services/chat_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

class ChatViewModel extends ChangeNotifier {
  final ChatRepository chatRepository;

  ChatViewModel({required this.chatRepository});

  LoadStatus listStatus = LoadStatus.idle;
  LoadStatus threadStatus = LoadStatus.idle;
  List<ConversationModel> conversations = [];
  ConversationThreadModel? thread;
  String? errorMessage;
  bool isMutating = false;
  int unreadCount = 0;

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) listStatus = LoadStatus.loading;
    errorMessage = null;
    if (!silent) notifyListeners();
    try {
      conversations = await chatRepository.listConversations();
      unreadCount = conversations.fold(
        0,
        (total, conversation) => total + conversation.unreadCount,
      );
      listStatus = LoadStatus.loaded;
    } on ApiException catch (error) {
      errorMessage = error.message;
      listStatus = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar suas conversas.';
      listStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    try {
      final count = await chatRepository.getUnreadCount();
      if (count != unreadCount) {
        unreadCount = count;
        notifyListeners();
      }
    } catch (_) {
      // O badge é informativo; uma falha de atualização não interrompe o app.
    }
  }

  Future<ConversationModel> openConversation(String professionalId) async {
    isMutating = true;
    notifyListeners();
    try {
      final conversation = await chatRepository.openConversation(
        professionalId,
      );
      return conversation;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> loadThread(
    String conversationId, {
    bool silent = false,
  }) async {
    if (!silent) threadStatus = LoadStatus.loading;
    if (!silent) notifyListeners();
    try {
      thread = await chatRepository.getThread(conversationId);
      threadStatus = LoadStatus.loaded;
      await refreshUnreadCount();
    } on ApiException catch (error) {
      errorMessage = error.message;
      threadStatus = LoadStatus.error;
      notifyListeners();
    } catch (_) {
      errorMessage = 'Não foi possível carregar esta conversa.';
      threadStatus = LoadStatus.error;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final normalized = body.trim();
    if (normalized.isEmpty) return;
    isMutating = true;
    notifyListeners();
    try {
      await chatRepository.sendMessage(
        conversationId: conversationId,
        body: normalized,
      );
      await loadThread(conversationId, silent: true);
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> createProposal({
    required String conversationId,
    required String title,
    required String description,
    required String category,
    required ServiceMode serviceMode,
    String? city,
    String? state,
    String? address,
    required PricingType pricingType,
    required double amount,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required bool isAllDay,
  }) async {
    isMutating = true;
    notifyListeners();
    try {
      await chatRepository.createProposal(
        conversationId: conversationId,
        title: title,
        description: description,
        category: category,
        serviceMode: serviceMode,
        city: city,
        state: state,
        address: address,
        pricingType: pricingType,
        amount: amount,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        isAllDay: isAllDay,
      );
      await loadThread(conversationId, silent: true);
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> respondToProposal({
    required String conversationId,
    required String proposalId,
    required bool accept,
  }) async {
    isMutating = true;
    notifyListeners();
    try {
      await chatRepository.respondToProposal(
        proposalId: proposalId,
        accept: accept,
      );
      await loadThread(conversationId, silent: true);
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }
}

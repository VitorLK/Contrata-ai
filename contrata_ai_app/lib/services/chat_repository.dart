import '../core/network/api_client.dart';
import '../models/chat_models.dart';
import '../models/professional_profile_model.dart';

class ChatRepository {
  final ApiClient apiClient;

  ChatRepository({required this.apiClient});

  Future<List<ConversationModel>> listConversations() async {
    final data = await apiClient.get('/chat/conversations', auth: true);
    return (data as List)
        .map(
          (item) => ConversationModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<ConversationModel> openConversation(String professionalId) async {
    final data = await apiClient.post('/chat/conversations', {
      'professional_id': professionalId,
    }, auth: true);
    return ConversationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ConversationThreadModel> getThread(String conversationId) async {
    final data = await apiClient.get(
      '/chat/conversations/$conversationId/messages',
      auth: true,
    );
    return ConversationThreadModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final data = await apiClient.post(
      '/chat/conversations/$conversationId/messages',
      {'body': body},
      auth: true,
    );
    return ChatMessageModel.fromJson(data as Map<String, dynamic>);
  }

  Future<JobProposalModel> createProposal({
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
    final data = await apiClient.post(
      '/chat/conversations/$conversationId/proposals',
      {
        'title': title,
        'description': description,
        'category': category,
        'service_mode': serviceMode.apiValue,
        'city': city,
        'state': state,
        'address': address,
        'pricing_type': pricingType.apiValue,
        'amount': amount,
        'scheduled_date': _apiDate(scheduledStart),
        'scheduled_start': scheduledStart.toUtc().toIso8601String(),
        'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
        'is_all_day': isAllDay,
      },
      auth: true,
    );
    return JobProposalModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ProposalResponseModel> respondToProposal({
    required String proposalId,
    required bool accept,
  }) async {
    final data = await apiClient.post('/chat/proposals/$proposalId/respond', {
      'action': accept ? 'aceitar' : 'recusar',
    }, auth: true);
    return ProposalResponseModel.fromJson(data as Map<String, dynamic>);
  }

  Future<int> getUnreadCount() async {
    final data = await apiClient.get('/chat/unread-count', auth: true);
    return int.tryParse(
          (data as Map<String, dynamic>)['unread_count']?.toString() ?? '',
        ) ??
        0;
  }
}

String _apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

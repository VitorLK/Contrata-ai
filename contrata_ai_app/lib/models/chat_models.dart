import 'professional_profile_model.dart';
import 'service_model.dart';

class ConversationModel {
  final String id;
  final String clientId;
  final String professionalId;
  final String clientName;
  final String professionalName;
  final String? professionalPhotoUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  const ConversationModel({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.clientName,
    required this.professionalName,
    this.professionalPhotoUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'].toString(),
      clientId: json['client_id'].toString(),
      professionalId: json['professional_id'].toString(),
      clientName: json['client_name']?.toString() ?? 'Contratante',
      professionalName: json['professional_name']?.toString() ?? 'Profissional',
      professionalPhotoUrl: json['professional_photo_url'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: _dateOrNull(json['last_message_at']),
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '') ?? 0,
      createdAt: _dateOrNull(json['created_at']) ?? DateTime.now(),
    );
  }

  String peerName(String currentUserId) =>
      currentUserId == clientId ? professionalName : clientName;
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String? senderName;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.senderName,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      senderId: json['sender_id'].toString(),
      body: json['body']?.toString() ?? '',
      senderName: json['sender_name'] as String?,
      createdAt: _dateOrNull(json['created_at']) ?? DateTime.now(),
      readAt: _dateOrNull(json['read_at']),
    );
  }
}

enum ProposalStatus { pendente, aceita, recusada, cancelada }

extension ProposalStatusX on ProposalStatus {
  String get label => switch (this) {
    ProposalStatus.pendente => 'Aguardando resposta',
    ProposalStatus.aceita => 'Proposta aceita',
    ProposalStatus.recusada => 'Proposta recusada',
    ProposalStatus.cancelada => 'Proposta cancelada',
  };

  static ProposalStatus fromApi(String? value) => switch (value) {
    'aceita' => ProposalStatus.aceita,
    'recusada' => ProposalStatus.recusada,
    'cancelada' => ProposalStatus.cancelada,
    _ => ProposalStatus.pendente,
  };
}

class JobProposalModel {
  final String id;
  final String conversationId;
  final String clientId;
  final String professionalId;
  final String title;
  final String description;
  final String? category;
  final ServiceMode serviceMode;
  final String? city;
  final String? state;
  final String? address;
  final PricingType pricingType;
  final double amount;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final bool isAllDay;
  final ProposalStatus status;
  final String? serviceId;
  final DateTime createdAt;

  const JobProposalModel({
    required this.id,
    required this.conversationId,
    required this.clientId,
    required this.professionalId,
    required this.title,
    required this.description,
    this.category,
    required this.serviceMode,
    this.city,
    this.state,
    this.address,
    required this.pricingType,
    required this.amount,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.isAllDay = false,
    required this.status,
    this.serviceId,
    required this.createdAt,
  });

  factory JobProposalModel.fromJson(Map<String, dynamic> json) {
    return JobProposalModel(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      clientId: json['client_id'].toString(),
      professionalId: json['professional_id'].toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category'] as String?,
      serviceMode:
          ServiceModeX.fromApi(json['service_mode']?.toString()) ??
          ServiceMode.presencial,
      city: json['city'] as String?,
      state: json['state'] as String?,
      address: json['address'] as String?,
      pricingType: PricingTypeX.fromApi(json['pricing_type']?.toString()),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      scheduledStart:
          _dateOrNull(json['scheduled_start']) ?? DateTime.now(),
      scheduledEnd: _dateOrNull(json['scheduled_end']) ?? DateTime.now(),
      isAllDay: json['is_all_day'] as bool? ?? false,
      status: ProposalStatusX.fromApi(json['status']?.toString()),
      serviceId: json['service_id'] as String?,
      createdAt: _dateOrNull(json['created_at']) ?? DateTime.now(),
    );
  }
}

class ConversationThreadModel {
  final ConversationModel conversation;
  final List<ChatMessageModel> messages;
  final List<JobProposalModel> proposals;

  const ConversationThreadModel({
    required this.conversation,
    this.messages = const [],
    this.proposals = const [],
  });

  factory ConversationThreadModel.fromJson(Map<String, dynamic> json) {
    return ConversationThreadModel(
      conversation: ConversationModel.fromJson(
        json['conversation'] as Map<String, dynamic>,
      ),
      messages: (json['messages'] as List? ?? const [])
          .map(
            (item) => ChatMessageModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      proposals: (json['proposals'] as List? ?? const [])
          .map(
            (item) => JobProposalModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class ProposalResponseModel {
  final JobProposalModel proposal;
  final ServiceModel? service;

  const ProposalResponseModel({required this.proposal, this.service});

  factory ProposalResponseModel.fromJson(Map<String, dynamic> json) {
    return ProposalResponseModel(
      proposal: JobProposalModel.fromJson(
        json['proposal'] as Map<String, dynamic>,
      ),
      service: json['service'] == null
          ? null
          : ServiceModel.fromJson(json['service'] as Map<String, dynamic>),
    );
  }
}

DateTime? _dateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

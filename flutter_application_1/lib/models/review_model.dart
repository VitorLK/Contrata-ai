class ReviewModel {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? clientName;

  const ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.clientName,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      clientName: json['client_name'] as String?,
    );
  }
}

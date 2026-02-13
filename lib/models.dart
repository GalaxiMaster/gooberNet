class Challenge {
  final String id;
  final String title;

  Challenge({
    required this.id,
    required this.title,
  });

  factory Challenge.fromMap(String id, Map<String, dynamic> data) {
    return Challenge(
      id: id,
      title: data['title'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
    };
  }
}

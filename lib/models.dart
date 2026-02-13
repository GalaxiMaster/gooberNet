class Challenge {
  final String id;
  final Map data;

  Challenge({
    required this.id,
    required this.data,
  });

  factory Challenge.fromMap(String id, Map<String, dynamic> data) {
    return Challenge(
      id: id,
      data: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...data,
    };
  }
}

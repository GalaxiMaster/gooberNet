class Challenge {
  final String id;
  final Map data;
  final List progressCount;
  final int progressTotal;

  Challenge({
    required this.id,
    required this.data,
    this.progressCount = const [],
    this.progressTotal = 9,
  });

  factory Challenge.fromMap(String id, Map<String, dynamic> data, {List? progress}) {
    return Challenge(
      id: id,
      data: data,
      progressCount: progress?[0] ?? [],
      progressTotal: progress?[1] ?? 9,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...data,
    };
  }

  void operator [](int other) {}
}

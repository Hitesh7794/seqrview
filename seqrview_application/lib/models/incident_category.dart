class IncidentCategory {
  final String uid;
  final String name;
  final String? description;

  IncidentCategory({
    required this.uid,
    required this.name,
    this.description,
  });

  factory IncidentCategory.fromJson(Map<String, dynamic> json) {
    return IncidentCategory(
      uid: json['uid'],
      name: json['name'],
      description: json['description'],
    );
  }
}

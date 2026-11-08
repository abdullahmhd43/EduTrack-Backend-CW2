class User {
  final String id;
  final String name;
  final String email;
  final String studentId;
  final String program;

  const User({required this.id, required this.name, required this.email, this.studentId = '', this.program = ''});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        studentId: (j['studentId'] ?? '').toString(),
        program: (j['program'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'studentId': studentId, 'program': program};

  User copyWith({String? name, String? studentId, String? program}) =>
      User(id: id, name: name ?? this.name, email: email, studentId: studentId ?? this.studentId, program: program ?? this.program);
}

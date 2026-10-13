final class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.parentId,
  });

  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;

  Folder copyWith({String? name}) => Folder(
        id: id,
        name: name ?? this.name,
        parentId: parentId,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Folder &&
      other.id == id &&
      other.name == name &&
      other.parentId == parentId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, parentId, createdAt);
}
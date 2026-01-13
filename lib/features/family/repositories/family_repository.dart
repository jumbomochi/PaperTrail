import 'package:paper_trail/core/database/database_helper.dart';
import 'package:paper_trail/features/family/models/family_member.dart';

class FamilyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<FamilyMember>> getAllMembers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('family_members', orderBy: 'name ASC');
    return maps.map((map) => FamilyMember.fromMap(map)).toList();
  }

  Future<FamilyMember?> getMemberById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'family_members',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FamilyMember.fromMap(maps.first);
  }

  Future<void> insertMember(FamilyMember member) async {
    final db = await _dbHelper.database;
    await db.insert('family_members', member.toMap());
  }

  Future<void> updateMember(FamilyMember member) async {
    final db = await _dbHelper.database;
    await db.update(
      'family_members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<void> deleteMember(String id) async {
    final db = await _dbHelper.database;
    await db.delete('family_members', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getMemberCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM family_members',
    );
    return result.first['count'] as int;
  }
}

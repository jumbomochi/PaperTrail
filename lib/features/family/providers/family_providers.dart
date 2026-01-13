import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_trail/features/family/models/family_member.dart';
import 'package:paper_trail/features/family/repositories/family_repository.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository();
});

final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  final repository = ref.watch(familyRepositoryProvider);
  return repository.getAllMembers();
});

final familyMemberByIdProvider = FutureProvider.family<FamilyMember?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(familyRepositoryProvider);
  return repository.getMemberById(id);
});

final familyMemberCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(familyRepositoryProvider);
  return repository.getMemberCount();
});

class FamilyNotifier extends StateNotifier<AsyncValue<List<FamilyMember>>> {
  final FamilyRepository _repository;

  FamilyNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadMembers();
  }

  Future<void> loadMembers() async {
    state = const AsyncValue.loading();
    try {
      final members = await _repository.getAllMembers();
      state = AsyncValue.data(members);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMember(FamilyMember member) async {
    await _repository.insertMember(member);
    await loadMembers();
  }

  Future<void> updateMember(FamilyMember member) async {
    await _repository.updateMember(member);
    await loadMembers();
  }

  Future<void> deleteMember(String id) async {
    await _repository.deleteMember(id);
    await loadMembers();
  }
}

final familyNotifierProvider =
    StateNotifierProvider<FamilyNotifier, AsyncValue<List<FamilyMember>>>((
      ref,
    ) {
      final repository = ref.watch(familyRepositoryProvider);
      return FamilyNotifier(repository);
    });

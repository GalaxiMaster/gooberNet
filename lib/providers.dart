import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goober_net/models.dart';
import 'package:goober_net/utils.dart';
import 'package:hive/hive.dart';

const globalBoxName = 'global_challenges';
const userBoxPrefix = 'user_challenges_';

class ChallengesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  late Box _globalBox;
  late Box _userBox;

  StreamSubscription? _globalSub;
  StreamSubscription? _userSub;

  ChallengesRepository(this.userId);

  Future<void> init() async {
    _globalBox = await Hive.openBox(globalBoxName);
    _userBox = await Hive.openBox('$userBoxPrefix$userId');

    _listenToFirestoreGlobal();
    _listenToFirestoreUser();
  }

  void _listenToFirestoreGlobal() {
    _globalSub = _firestore
        .collection('Challenges')
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        await _globalBox.put(doc.id, hiveSafe(doc.data()));
      }
    });
  }


  void _listenToFirestoreUser() {
    _userSub = _firestore
        .collection('Users')
        .doc(userId)
        .collection('CustomChallenges')
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        await _userBox.put(doc.id, hiveSafe(doc.data()));
      }
    });
  }

  Stream<Map<String, Challenge>> watchGlobal() async* {
    yield _readGlobal();

    yield* _globalBox.watch().map((_) => _readGlobal());
  }

  Map<String, Challenge> _readGlobal() {
    return {
      for (final key in _globalBox.keys)
        key: Challenge.fromMap(
          key,
          Map<String, dynamic>.from(_globalBox.get(key)),
        ),
    };
  }

  Stream<Map<String, Challenge>> watchUser() async* {
    yield _readUser();

    yield* _userBox.watch().map((_) => _readUser());
  }

  Map<String, Challenge> _readUser() {
    return {
      for (final key in _userBox.keys)
        key: Challenge.fromMap(
          key,
          Map<String, dynamic>.from(_userBox.get(key)),
        ),
    };
  }

  void dispose() {
    _globalSub?.cancel();
    _userSub?.cancel();
  }
  
  Future<void> addUserChallenge(Map<String, dynamic> data) async {
    final docRef = _firestore
        .collection('Users')
        .doc(userId)
        .collection('CustomChallenges')
        .doc(); // Auto Gen Id

    final autoId = docRef.id;

    await docRef.set(data);

    await _userBox.put(autoId, hiveSafe(data));
  }
}

final repositoryProvider = FutureProvider.family<ChallengesRepository, String>((ref, userId) async {
  final repo = ChallengesRepository(userId);
  await repo.init();
  ref.onDispose(repo.dispose);
  return repo;
});

final globalChallengesProvider = StreamProvider.family<Map<String, Challenge>, String>((ref, userId) async* {
  final repo = await ref.watch(repositoryProvider(userId).future);
  yield* repo.watchGlobal();
});

final userChallengesProvider = StreamProvider.family<Map<String, Challenge>, String>((ref, userId) async* {
  final repo = await ref.watch(repositoryProvider(userId).future);
  yield* repo.watchUser();
});

import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';
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
  late Box _progressBox;
  late Box _userJoinsBox;

  StreamSubscription? _globalSub;
  StreamSubscription? _userSub;
  StreamSubscription? _joinsSub;

  StreamController<void>? _progressUpdateController;

  ChallengesRepository(this.userId);

  Future<void> init() async {
    _globalBox = await Hive.openBox(globalBoxName);
    _userBox = await Hive.openBox('$userBoxPrefix$userId');
    _progressBox = await Hive.openBox('progress_$userId');
    _userJoinsBox = await Hive.openBox('Joined_$userBoxPrefix$userId');

    _listenToFirestoreGlobal();
    _listenToFirestoreUser();
    _listenToFirestoreUserJoins();
    await _validateProgressCache();
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
  
  void _listenToFirestoreUserJoins() {
    _joinsSub = _firestore
        .collection('Users')
        .doc(userId)
        .collection('JoinedChallenges')
        .snapshots()
        .listen((snapshot) async {
      final firestoreIds = snapshot.docs.map((d) => d.id).toSet();

      for (final doc in snapshot.docs) {
        await _userJoinsBox.put(doc.id, hiveSafe(doc.data()));
      }

      final hiveKeys = _userJoinsBox.keys.cast<String>().toSet();
      final toDelete = hiveKeys.difference(firestoreIds);
      for (final key in toDelete) {
        await _userJoinsBox.delete(key);
      }
    });
  }

  Map<String, Challenge> _readUserWithProgress() {
    return {
      for (final key in _userBox.keys)
        key: Challenge.fromMap(
          key,
          Map<String, dynamic>.from(_userBox.get(key)),
          progress: List.from(_progressBox.get(key, defaultValue: [[], 9])),
        ),
    };
  }
  
  Stream<Map<String, Challenge>> watchUserWithProgress() async* {
    yield _readUserWithProgress();

    yield* StreamGroup.merge([
      _userBox.watch(),
      _progressBox.watch(), // Reacts to progress changes
    ]).map(
      (_) => _readUserWithProgress()
    );
  }
  
  Stream<Map<String, Challenge>> watchGlobalWithProgress() async* {
    yield _readGlobalWithProgress();

    yield* StreamGroup.merge([
      _globalBox.watch(),
      _progressBox.watch(), // Reacts to progress changes
    ]).map(
      (_) => _readGlobalWithProgress()
    );
  }

  Map<String, Challenge> _readGlobalWithProgress() {
    return {
      for (final key in _globalBox.keys)
        key: Challenge.fromMap(
          key,
          Map<String, dynamic>.from(_globalBox.get(key)),
          progress: List.from(_progressBox.get(key, defaultValue: [[], 9])),
        ),
    };
  }
  
  Stream<Map> watchJoins() async* {
    yield _readJoins();

    yield* _userJoinsBox.watch().map((_) => _readJoins());
  }

  Map _readJoins() {
    return _userJoinsBox.toMap();
  }

  void dispose() {
    _globalSub?.cancel();
    _userSub?.cancel();
    _joinsSub?.cancel();
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
  Future<void> deleteUserChallenge(String challengeId) async {
    final docRef = _firestore
        .collection('Users')
        .doc(userId)
        .collection('CustomChallenges')
        .doc(challengeId); // Auto Gen Id

    await docRef.delete();

    await _userBox.delete(challengeId);
  }
  Future<void> recordImageAdded(String challengeId, int imageIndex) async {
    final current = _progressBox.get(challengeId, defaultValue: [[], 9]) as List;
    List progress = current.first;
    if (!progress.contains(imageIndex)) {
      await _progressBox.put(challengeId, [current.first..add(imageIndex), 9]);
    }
  }

  Future<void> recordImageRemoved(String challengeId, int imageIndex) async {
    final current = _progressBox.get(challengeId, defaultValue: [0, 9]) as List;
    await _progressBox.put(challengeId, [current.first..remove(imageIndex), 9]);
  }

  Future<void> _validateProgressCache() async {
    final path = await localPath;
    
    bool needsUpdate = false;
    
    for (final MapEntry challenge in {..._globalBox.toMap(), ..._userBox.toMap()}.entries) {
      final List<int> actualCount = [];
      
      for (int i = 0; i < (challenge.value['maxProgress'] ?? 9); i++) {
        final file = File('$path/challenge_${challenge.key}$i.png');
        if (await file.exists()) {
          actualCount.add(i);
        }
      }
      
      final cached = _progressBox.get(challenge.key, defaultValue: [[], 9]) as List;
      if (cached[0] != actualCount) {
        await _progressBox.put(challenge.key, [actualCount, 9]);
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      _progressUpdateController?.add(null);
    }
  }
}

final repositoryProvider = FutureProvider.family<ChallengesRepository, String>((ref, userId) async {
  final repo = ChallengesRepository(userId);
  await repo.init();
  ref.onDispose(repo.dispose);
  return repo;
});

final userChallengesProvider = StreamProvider.family<Map<String, Challenge>, String>((ref, userId) async* {
  final repo = await ref.watch(repositoryProvider(userId).future);
  yield* repo.watchUserWithProgress();
});

final globalChallengeProvider = StreamProvider.family<Map<String, Challenge>, String>((ref, userId) async* {
  final repo = await ref.watch(repositoryProvider(userId).future);
  yield* repo.watchGlobalWithProgress();
});

final globalJoinsProvider = StreamProvider.family<Map, String>((ref, userId) async* {
  final repo = await ref.watch(repositoryProvider(userId).future);
  yield* repo.watchJoins();
});

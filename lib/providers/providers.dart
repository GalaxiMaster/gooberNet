import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostsNotifier extends AsyncNotifier<List<DocumentSnapshot<Map<String, dynamic>>>> {
  static const int _pageSize = 10;

  final Query<Map<String, dynamic>> _baseQuery = FirebaseFirestore.instance
      .collection('Posts')
      .orderBy('postDate', descending: true)
      .limit(_pageSize);

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> build() async {
    final snapshot = await _baseQuery.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    _hasMore = snapshot.docs.length == _pageSize;

    return snapshot.docs;
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || state.isLoading) return;

    _isLoadingMore = true;

    try {
      final currentPosts = state.value ?? [];

      if (_lastDocument == null) {
        _isLoadingMore = false;
        return;
      }

      final nextQuery = FirebaseFirestore.instance
          .collection('Posts')
          .orderBy('postDate', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await nextQuery.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        state = AsyncData([
          ...currentPosts,
          ...snapshot.docs,
        ]);
      }

      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> refresh() async {
    _lastDocument = null;
    _hasMore = true;
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  void addPost(DocumentReference docRef) async {
      final current = state.value;
      if (current == null) return;

      final newDoc = await docRef.get()
          as DocumentSnapshot<Map<String, dynamic>>;

      final newState = [
        newDoc,
        ...current,
      ];

      state = AsyncValue.data(newState);
  }

  void deletePost(DocumentSnapshot post) {
    final newState = List<DocumentSnapshot<Map<String, dynamic>>>.from(state.value!);

    newState.removeWhere((doc) => doc.id == post.id);

    state = AsyncValue.data(newState);


    if (_lastDocument != null && post.id == _lastDocument!.id) {
      _lastDocument = newState.isNotEmpty ? newState.last : null;
    }

    state = AsyncValue.data(newState);
  }

}

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<DocumentSnapshot<Map<String, dynamic>>>>(PostsNotifier.new);

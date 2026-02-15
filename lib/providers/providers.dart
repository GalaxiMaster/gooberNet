import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostsNotifier extends AsyncNotifier<List<QueryDocumentSnapshot<Map<String, dynamic>>>> {
  static const int _pageSize = 10;

  final Query<Map<String, dynamic>> _baseQuery = FirebaseFirestore.instance
      .collection('Posts')
      .orderBy('postDate', descending: true)
      .limit(_pageSize);

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> build() async {
    final snapshot = await _baseQuery.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    _hasMore = snapshot.docs.length == _pageSize;

    return snapshot.docs;
  }
  Future<void> refreshData() async {
    final snapshot = await _baseQuery.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    _hasMore = snapshot.docs.length == _pageSize;

    state = AsyncData([
      ...snapshot.docs,
    ]);
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
}

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<QueryDocumentSnapshot<Map<String, dynamic>>>>(PostsNotifier.new);

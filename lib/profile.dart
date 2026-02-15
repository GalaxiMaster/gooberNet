import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:goober_net/main.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ProfilePage extends StatefulWidget {
  final String uid;
  final Map userData;
  const ProfilePage({super.key, required this.uid, required this.userData});
  
  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final int _postsPerPage = 15;
  
  List<QueryDocumentSnapshot> _posts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _isInitialLoading = true;
  
  bool isFollowed = false;
  int postCount = 0;
  Map<String, Map<String, dynamic>> postDataCache = {};
  String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialize();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadInitialPosts(),
      _getIsFollowed(),
      _getPostCount(),
    ]);
  }

  Future<void> _loadInitialPosts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.uid)
          .collection('Posts')
          .orderBy('postDate', descending: true)
          .limit(_postsPerPage)
          .get();

      if (mounted) {
        setState(() {
          _posts = snapshot.docs;
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMorePosts = snapshot.docs.length == _postsPerPage;
          _isInitialLoading = false;
        });
        
        // Preload post data for initial posts
        _preloadPostData(snapshot.docs);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
      debugPrint('Error loading posts: $e');
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.uid)
          .collection('Posts')
          .orderBy('postDate', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage)
          .get();

      if (mounted) {
        setState(() {
          _posts.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMorePosts = snapshot.docs.length == _postsPerPage;
          _isLoadingMore = false;
        });
        
        // Preload post data for newly loaded posts
        _preloadPostData(snapshot.docs);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
      debugPrint('Error loading more posts: $e');
    }
  }

  void _preloadPostData(List<QueryDocumentSnapshot> docs) {
    for (var doc in docs) {
      if (!postDataCache.containsKey(doc.id)) {
        FirebaseFirestore.instance
            .collection('Posts')
            .doc(doc.id)
            .get()
            .then((snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              postDataCache[doc.id] = snapshot.data()!;
            });
          }
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMorePosts();
    }
  }

  Future<void> _getIsFollowed() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUid)
          .collection('Following')
          .doc(widget.uid)
          .get();

      if (mounted) {
        setState(() => isFollowed = doc.exists);
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _getPostCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.uid)
          .collection('Posts')
          .count()
          .get();

      if (mounted) {
        setState(() => postCount = snapshot.count ?? 0);
      }
    } catch (e) {
      debugPrint('Error getting post count: $e');
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _posts.clear();
      _lastDocument = null;
      _hasMorePosts = true;
      postDataCache.clear();
    });
    
    await Future.wait([
      _loadInitialPosts(),
      _getIsFollowed(),
      _getPostCount(),
    ]);
  }

  Future<void> _toggleFollow() async {
    try {
      if (isFollowed) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUid)
            .collection('Following')
            .doc(widget.uid)
            .delete();
        await FirebaseMessaging.instance
            .unsubscribeFromTopic("user_followers_${widget.uid}");
      } else {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUid)
            .collection('Following')
            .doc(widget.uid)
            .set({});
        
        await requestNotificationPermission();
        await FirebaseMessaging.instance
            .subscribeToTopic("user_followers_${widget.uid}");
        debugPrint("subscribed to user_followers_${widget.uid}");
      }
      
      if (mounted) {
        setState(() => isFollowed = !isFollowed);
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update follow status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.userData['displayName'] ?? 'User'}'),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: _buildProfileHeader(),
            ),
            
            const SliverToBoxAdapter(
              child: Divider(height: 1, thickness: 0.5),
            ),
            
            if (_isInitialLoading)
              SliverToBoxAdapter(
                child: _buildSkeletonGrid(),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(1),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildGridItem(_posts[index], index);
                    },
                    childCount: _posts.length,
                  ),
                ),
              ),
            
            // Loading More Indicator
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(
                tag: 'profile_${widget.uid}',
                child: CircleAvatar(
                  radius: 35,
                  backgroundImage: NetworkImage(
                    widget.userData['profilePictureUrl'] ?? '',
                  ),
                ),
              ),
              const SizedBox(width: 20),
                        
              Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.userData['displayName'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),            
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Posts', postCount),
                    ],
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Follow Button (only show if not own profile)
          if (currentUid != widget.uid)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: _toggleFollow,
                style: OutlinedButton.styleFrom(
                  backgroundColor: isFollowed 
                      ? Colors.transparent 
                      : Colors.deepPurple,
                  foregroundColor: isFollowed 
                      ? Colors.white 
                      : Colors.white,
                  side: BorderSide(
                    color: isFollowed 
                        ? Colors.grey.shade700 
                        : Colors.deepPurple,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isFollowed ? 'Following' : 'Follow',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(QueryDocumentSnapshot doc, int index) {
    final cachedData = postDataCache[doc.id];
    
    if (cachedData == null) {
      return _buildSkeletonItem();
    }
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostPage(
                docs: _posts,
                initialIndex: index,
              ),
            ),
          );
        },
        onLongPress: () {
          if (cachedData['imageDetails'] != null && 
              cachedData['imageDetails'].isNotEmpty) {
            ImageOverlay.show(
              context,
              cachedData['imageDetails'][0],
            );
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate optimal cache size based on actual widget size and device pixel ratio
            final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
            final cacheWidth = (constraints.maxWidth * devicePixelRatio).round();
            final cacheHeight = (constraints.maxHeight * devicePixelRatio).round();
            
            return CachedNetworkImage(
              imageUrl: cachedData['imageDetails'] != null && 
                         cachedData['imageDetails'].isNotEmpty
                  ? 'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${cachedData['imageDetails'][0]['imageId']}'
                  : '',
              cacheKey: cachedData['imageDetails'] != null && 
                         cachedData['imageDetails'].isNotEmpty
                  ? cachedData['imageDetails'][0]['imageId']
                  : null,
              fit: BoxFit.cover,
              memCacheWidth: cacheWidth,
              memCacheHeight: cacheHeight,
              maxHeightDiskCache: cacheHeight,
              maxWidthDiskCache: cacheWidth,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (context, url) => _buildSkeletonItem(),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade900,
                child: const Icon(Icons.error_outline, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
          childAspectRatio: 0.75,
        ),
        itemCount: 9,
        itemBuilder: (context, index) => _buildSkeletonItem(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentUid == widget.uid 
                ? 'Share your first photo or video'
                : 'When they post, you\'ll see them here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class PostPage extends StatefulWidget {
  final List<QueryDocumentSnapshot> docs;
  final int initialIndex;

  const PostPage({
    super.key,
    required this.docs,
    required this.initialIndex,
  });

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final ItemScrollController _scrollController = ItemScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
      ),
      body: ScrollablePositionedList.builder(
        itemScrollController: _scrollController,
        initialScrollIndex: widget.initialIndex,
        itemCount: widget.docs.length,
        itemBuilder: (context, i) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('Posts')
                .doc(widget.docs[i].id)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 400,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.data == null) {
                return const SizedBox.shrink();
              }

              return PostTemplate(
                post: snapshot.data!,
                postId: widget.docs[i].id,
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('User granted permission');
  } else {
    debugPrint('User declined or has not accepted permission');
  }
}
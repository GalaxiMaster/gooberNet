import 'dart:async';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudflare_r2/cloudflare_r2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:goober_net/challenges.dart';
import 'package:goober_net/utils.dart';
import 'package:goober_net/profile.dart';
import 'package:goober_net/settings.dart';
import 'package:goober_net/sign_in_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();
  await CloudFlareR2.init(
    accountId: dotenv.get('accountId'),
    accessKeyId: dotenv.get('accessKeyId'),
    secretAccessKey: dotenv.get('secretAccessKey'),
  );
  runApp(const MyApp());
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const SignInPage();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color.fromARGB(255, 12, 16, 20),
        appBarTheme: AppBarTheme(
          backgroundColor: Color.fromARGB(255, 12, 16, 20),
        ),
        colorScheme: ColorScheme.dark()
      ),      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => HomePage(),
        '/SignIn': (context) => const SignInPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int selectedPageIndex = 1;
  final posts = FirebaseFirestore.instance.collection('Posts').orderBy('postDate', descending: true); 
  final likes = FirebaseFirestore.instance.collection('Likes');
  final _pages = [    
    HomeFeedPage(),    
    ChallengesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedPageIndex,
        onTap: (i) => setState(() => selectedPageIndex = i),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            activeIcon: Icon(Icons.access_time),
            label: 'Challenges',
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedPageIndex,
        children: _pages,
      ),
      floatingActionButton: selectedPageIndex == 0 ? createPostFab() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    switch (selectedPageIndex) {
      case 0:
        return AppBar(
          title: const Text('Thingy'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage()),
              ),
            ),
          ],
        );
      case 1:
        return AppBar(
          title: Text('Active Challenges'),
          centerTitle: true,
        );
      default:
        return AppBar();
    }
  }
  
  Widget createPostFab() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: () async{
          final picker = ImagePicker();
          final List<XFile> picked = await picker.pickMultiImage();
          if (picked.isEmpty) return;
          if (!mounted) return;
          postAndUpload(picked, context);
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _HomeFeedPageState createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  @override
  Widget build(BuildContext context) {
    final posts = FirebaseFirestore.instance.collection('Posts').orderBy('postDate', descending: true); 
    final likes = FirebaseFirestore.instance.collection('Likes');
    return StreamBuilder(
      stream: (posts.snapshots()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
    
        return ListView(
          cacheExtent: 1000,
          children: docs.map((d) => PostTemplate(postData: d.data(), favorited: likes.doc(d.id), postId: d.id)).toList(),
        );
      },
    );
  }
}

Future<Map> getUser(String userId) async {
  DocumentSnapshot doc = await FirebaseFirestore.instance
      .collection('Users')
      .doc(userId)
      .get();

  return doc.data() as Map;
}

class PostTemplate extends StatefulWidget {
  final Map postData;
  final DocumentReference? favorited;
  final String postId;

  const PostTemplate({
    super.key,
    required this.postData,
    required this.favorited,
    required this.postId,
  });

  @override
  State<PostTemplate> createState() => _PostTemplateState();
}

class _PostTemplateState extends State<PostTemplate> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  late Future<Map> userData;
  late DocumentReference postRef;
  late String? currentUid;

  late Map postData;
  late Future<Map> future = checkImageData();

  late int likeCount;
  late bool hasLiked = false;

  @override
  void initState() {
    super.initState();

    userData = getUser(widget.postData['authorID']);
    postRef = FirebaseFirestore.instance.collection('Posts').doc(widget.postId);
    currentUid = FirebaseAuth.instance.currentUser?.uid;
    postData = widget.postData;
    likeCount = (postData['likeCount'] ?? 0) as int;
    _loadInitialLike();
  }

  Future<void> _loadInitialLike() async {
    final doc = await postRef.collection('Likes').doc(currentUid).get();
    if (!mounted) return;
    setState(() => hasLiked = doc.exists);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> likePost() async {
    if (currentUid == null) {
      Navigator.pushNamed(context, '/SignIn');
      return;
    }
    setState(() {
      hasLiked = !hasLiked;
      likeCount += hasLiked ? 1 : -1;
    });
    final likeDocRef = postRef.collection('Likes').doc(currentUid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final likeSnapshot = await tx.get(likeDocRef);
      if (likeSnapshot.exists) {
        tx.delete(likeDocRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeDocRef, {
          'createdAt': FieldValue.serverTimestamp(),
          'displayName': FirebaseAuth.instance.currentUser?.displayName,
          'photoUrl': FirebaseAuth.instance.currentUser?.photoURL,
          'userId': currentUid,
        });
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Future<Map<dynamic, dynamic>> checkImageData() async {
    final images = (widget.postData['imageDetails'] as List);
    for (var (i, image) in images.indexed) {
      if (image['height'] == null || image['width'] == null) {
        final ImageInfo info = await _getImageInfo('https://pub-b665727283304785a65fc86be829fa67.r2.dev/${image['imageId']}');
        postData['imageDetails'][i]['width'] = info.image.width.toDouble();
        postData['imageDetails'][i]['height'] = info.image.height.toDouble();

        await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).update({
          'imageDetails': postData['imageDetails'],
        });
      }
    }
    return postData;
  }
  double? findHeightestImage(postData) {
    double? heightest;
    for (var image in postData) {
      final double aspectRatio = image['width'] / image['height'];
      if (heightest == null || aspectRatio < heightest) {
        heightest = aspectRatio;
      }
    }
    return heightest;
  }

  @override
  Widget build(BuildContext context) {
    final postDate = postData['postDate'].toDate();
    final minutesPassed = DateTime.now().difference(postDate).inMinutes;
    
    return Column(
      children: [
        Stack(
          children: [
            postData.containsKey('imageDetails') && postData['imageDetails'] != null
              ? FutureBuilder(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data'));
                  } else if (snapshot.hasData) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).width * 3/2 // Stop images being too long
                      ),
                      child: SizedBox( // function height could be the problem -> add to caching map
                        height: findHeightestImage(postData['imageDetails']) != null ? MediaQuery.sizeOf(context).width / findHeightestImage(postData['imageDetails'])! : MediaQuery.sizeOf(context).width,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: postData['imageDetails'].length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onLongPress: () {
                                ImageOverlay.show(
                                  context,
                                  postData['imageDetails'][index]
                                );
                              },
                              onDoubleTap: () => likePost(),
                              child: Center(
                                child: CachedNetworkImage(
                                  imageUrl: (postData['imageDetails'][index]['imageId']?.isNotEmpty ?? false)
                                      ? 'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${postData['imageDetails'][index]['imageId']}'
                                      : 'https://via.placeholder.com/150',
                                  width: MediaQuery.sizeOf(context).width,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(child: CircularProgressIndicator()),
                                  errorWidget: (_, __, ___) => const SizedBox(),
                                ),
                              )
                            );
                          },
                          onPageChanged: (newPage) {
                            setState(() => _currentPage = newPage);
                          },
                        ),
                      ),
                    );
                  } else {
                    return const Center(child: Text('No data available'));
                  }
                },
              )
              : Container(
                  height: MediaQuery.sizeOf(context).width,
                  width: MediaQuery.sizeOf(context).width,
                  color: Colors.grey.shade700,
                ),

            Positioned(
              top: 5,
              left: 5,
              child: FutureBuilder(
                future: userData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return const Text('Error');
                  } else if (!snapshot.hasData) {
                    return const Text('No data');
                  }

                  final data = snapshot.data!;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(
                            uid: postData['authorID'],
                            userData: data,
                          ),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: Row(
                        spacing: 5,
                        children: [
                          data['profilePictureUrl'] != null
                              ? CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(
                                    data['profilePictureUrl'],
                                  ),
                                  radius: 15,
                                )
                              : const CircleAvatar(
                                  radius: 15,
                                  child: Icon(Icons.person),
                                ),
                          Text(data['displayName']),
                          Spacer(),
                          if (currentUid == postData['authorID'])
                          GestureDetector(
                            onTap: (){
                              showModalBottomSheet(
                                context: context,
                                builder: (ctx) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.delete),
                                          title: Text('Delete Post'),
                                          onTap: () async {
                                            final bool? res = await showDialog(
                                              context: context, 
                                              builder: (context){
                                                return AlertDialog(
                                                  title: Text('Confirm Deletion'),
                                                  content: Text('Are you sure you want to delete this post? This action cannot be undone.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: (){
                                                        Navigator.pop(context, false);
                                                      }, 
                                                      child: Text('Cancel')
                                                    ),
                                                    TextButton(
                                                      onPressed: (){
                                                        Navigator.pop(context, true);
                                                      }, 
                                                      child: Text('Delete', style: TextStyle(color: Colors.red),)
                                                    ),
                                                  ],
                                                );
                                              }
                                            );
                                            if (res != true) return;
                                            if (!ctx.mounted) return;
                                            Navigator.pop(ctx);
                                            for (var image in postData['imageDetails']){
                                              await CloudFlareR2.deleteObject(
                                                bucket: 'images',
                                                objectName: image['imageId'],
                                              );
                                            }
                                            await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).delete();
                                            await FirebaseFirestore.instance.collection('Users').doc(currentUid).collection('Posts').doc(widget.postId).delete();
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.more_vert,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (postData['imageDetails'].length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    postData['imageDetails'].length,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        _currentPage == index
                            ? Icons.circle
                            : Icons.circle_outlined,
                        color: Colors.grey.shade200,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Column(
            children: [
              Row(
                spacing: 20,
                children: [
                  GestureDetector(
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) {
                          return FutureBuilder<QuerySnapshot>(
                            future: postRef.collection('Likes').orderBy('createdAt', descending: true).limit(50).get(),
                            builder: (context, likesSnap) {
                              if (!likesSnap.hasData) {
                                return const SizedBox(
                                  height: 200,
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }

                              final docs = likesSnap.data!.docs;

                              if (docs.isEmpty) {
                                return const SizedBox(
                                  height: 200,
                                  child: Center(
                                      child: Text('No likes yet')),
                                );
                              }

                              return SizedBox(
                                height: 300,
                                child: ListView(
                                  children: docs.map((d) {
                                    final data = d.data() as Map<String, dynamic>;
                                    return ListTile(
                                      leading: data['photoUrl'] != null
                                          ? CircleAvatar(
                                              backgroundImage: NetworkImage(data['photoUrl']),
                                            )
                                          : const CircleAvatar(
                                              child: Icon(Icons.person),
                                            ),
                                      title: Text(
                                        data['displayName'] ?? data['userId'] ?? 'User',
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    onTap: () => likePost(),
                    child: Row(
                      spacing: 5,
                      children: [
                        Icon(hasLiked
                            ? Icons.favorite
                            : Icons.favorite_border
                          ),
                        Text('$likeCount'),
                      ],
                    ),
                  ),

                  Row(
                    spacing: 5,
                    children: const [
                      Icon(Icons.comment_outlined),
                      Text('0'),
                    ],
                  ),
                ],
              ),

              // CAPTION
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  child: Text(postData['caption']),
                ),
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  child: Text(
                    minutesPassed ~/ 1440 > 0
                        ? '${minutesPassed ~/ 1440} days ago'
                        : minutesPassed ~/ 60 >= 1
                            ? '${minutesPassed ~/ 60} hours ago'
                            : '$minutesPassed minutes ago',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
}


class ImageOverlay {
  static void show(BuildContext context, Map imageData) {
    late OverlayEntry overlay;

    overlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
            Center(
              child: Builder(
                builder: (context) {
                  final imgWidth = imageData['width'];
                  final imgHeight = imageData['height'];

                  final screenWidth = MediaQuery.of(context).size.width;
                  final maxWidth = screenWidth * 0.95;

                  final scaleFactor = maxWidth / imgWidth;
                  final displayHeight = imgHeight * scaleFactor;

                  return SizedBox(
                    width: maxWidth,
                    height: displayHeight,
                    child: PhotoView.customChild(
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 4,
                      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: imageData['imageId'] != null
                              ? 'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${imageData['imageId']}'
                              : '',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => overlay.remove(),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(overlay);
  }


}  

Future<ImageInfo> _getImageInfo(String url) async {
  final completer = Completer<ImageInfo>();
  final image = NetworkImage(url);

  image.resolve(const ImageConfiguration()).addListener(
    ImageStreamListener((ImageInfo info, _) {
      completer.complete(info);
    }),
  );

  return completer.future;
}

Future<Map<String, double>> getImageSize(XFile file) async {
  final bytes = await file.readAsBytes();

  final ui.Image image = await decodeImageFromList(bytes);

  return {
    'width': image.width.toDouble(),
    'height': image.height.toDouble(),
  };
}
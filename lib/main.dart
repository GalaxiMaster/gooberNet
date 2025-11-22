import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudflare_r2_uploader/cloudflare_r2_uploader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:goober_net/profile.dart';
import 'package:goober_net/settings.dart';
import 'package:goober_net/sign_in_page.dart';
import 'package:goober_net/upload_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();

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
  final users = FirebaseFirestore.instance.collection('Posts').orderBy('postDate', descending: true);
  final likes = FirebaseFirestore.instance.collection('Likes');

  @override
  void initState() {
    super.initState();

  }
  void fetchPostContent() async {
    
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: users.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;

        return Scaffold(
            appBar: AppBar(
              title: const Text('Thingy'),
              actions: [
                IconButton(
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage())
                    );
                  },
                  icon: const Icon(Icons.settings),
                )
              ],
            ),
            body: Stack(
              children: [
                ListView(
                  children: docs.map((d) => PostTemplate(postData: d.data(), favorited: likes.doc(d.id), postId: d.id)).toList(),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: () async{
                      final picker = ImagePicker();
                      final List<XFile> picked = await picker.pickMultiImage();
                      if (picked.isEmpty) return;
                      for (XFile image in picked){
                        final fileSize = await image.length(); // in bytes

                        const maxSize = 5 * 1024 * 1024; // 5 MB limit

                        if (fileSize > maxSize) {
                          if (mounted){
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("File too large. Maximum allowed is 5MB."),
                              ),
                            );    
                          }
                          return;                  
                        }
                      }


                      final details = await Navigator.push(
                        // ignore: use_build_context_synchronously
                        context,
                        MaterialPageRoute(builder: (context) => UploadPage(imagePath: picked.map((p)=>p.path).toList())),
                      );
                      if (details == null) return;
                      List<String> imageUIDs = [];
                      for (XFile image in picked){
                        final bytes = await image.readAsBytes();
                        final uploader = CloudflareR2Uploader(
                          accountId: dotenv.get('accountId'), 
                          accessKeyId: dotenv.get('accessKeyId'), 
                          secretAccessKey: dotenv.get('secretAccessKey'), 
                          bucketName: 'images'
                        );

                        // Build a unique filename to avoid collisions in the bucket/DB.
                        final originalName = image.name;
                        final dotIndex = originalName.lastIndexOf('.');
                        final extension = dotIndex != -1 ? originalName.substring(dotIndex) : '';
                        final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? 'anon'}$extension';
                        imageUIDs.add(uniqueName);
                        // Upload and capture the returned URL so we can store it in Firestore.
                        await uploader.uploadFile(
                          fileBytes: bytes,
                          fileName: uniqueName,
                          onProgress: (progress) {
                            // setState(() {
                            //   _progress = progress;
                            // });
                          },
                        );
                      }

                      final now = DateTime.now();
                      DocumentReference docId = await FirebaseFirestore.instance.collection('Posts').add({
                        'authorID': FirebaseAuth.instance.currentUser!.uid,
                        'postDate': now,
                        'likeCount': 0,
                        'caption': details,
                        'imageName': imageUIDs,
                      });
                      await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).collection('Posts').doc(docId.id).set({
                        'postDate': now,
                      });
                    },
                    child: Icon(Icons.add),
                  ),
                )
              ],
            )
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

  @override
  void initState() {
    super.initState();

    userData = getUser(widget.postData['authorID']);
    postRef = FirebaseFirestore.instance
        .collection('Posts')
        .doc(widget.postId);
    currentUid = FirebaseAuth.instance.currentUser?.uid;
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

  @override
  Widget build(BuildContext context) {
    final postData = widget.postData;

    final postDate = postData['postDate'].toDate();
    final minutesPassed = DateTime.now().difference(postDate).inMinutes;

    return Column(
      children: [
        Stack(
          children: [
            postData.containsKey('imageName') && postData['imageName'] != null
                ? SizedBox(
                    height: MediaQuery.sizeOf(context).width, // ! Default to square since image dimensions are unknown
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: postData['imageName'].length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onLongPress: () {
                            ImageOverlay.show(
                              context,
                              'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${postData['imageName'][index]}',
                            );
                          },
                          onDoubleTap: () => likePost(),
                          child: Center(
                            child: CachedNetworkImage(
                              imageUrl: 'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${postData['imageName'][index]}',
                              width: MediaQuery.sizeOf(context).width,
                              fit: BoxFit.cover,   // <-- important
                              placeholder: (_, __) => Center(child: CircularProgressIndicator()),
                            ),
                          )
                        );
                      },
                      onPageChanged: (newPage) {
                        setState(() => _currentPage = newPage);
                      },
                    ),
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
                      ],
                    ),
                  );
                },
              ),
            ),

            if (postData['imageName'].length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    postData['imageName'].length,
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
                  StreamBuilder<DocumentSnapshot>(
                    stream: currentUid == null
                        ? const Stream.empty()
                        : postRef.collection('Likes').doc(currentUid).snapshots(),
                    builder: (context, snap) {
                      final hasLiked = snap.hasData && snap.data!.exists;

                      final likeCount = (postData['likeCount'] ?? 0) as int;

                      return GestureDetector(
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
                                      child: Center(
                                          child: CircularProgressIndicator()),
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
                      );
                    },
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
  static void show(BuildContext context, String imageUrl) {
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
              child: FutureBuilder<ImageInfo>(
                future: _getImageInfo(imageUrl),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final info = snapshot.data!;
                  final imgWidth = info.image.width.toDouble();
                  final imgHeight = info.image.height.toDouble();

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
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
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
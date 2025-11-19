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
                  children: docs.map((d) => postTemplate(context, d.data(), likes.doc(d.id), d.id)).toList(),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: () async{
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      if (picked == null) return;

                      final details = await Navigator.push(
                        // ignore: use_build_context_synchronously
                        context,
                        MaterialPageRoute(builder: (context) => UploadPage(imagePath: picked.path)),
                      );
                      if (details == null) return;

                      final bytes = await picked.readAsBytes();
                      final uploader = CloudflareR2Uploader(
                        accountId: dotenv.get('accountId'), 
                        accessKeyId: dotenv.get('accessKeyId'), 
                        secretAccessKey: dotenv.get('secretAccessKey'), 
                        bucketName: 'images'
                      );

                      // Build a unique filename to avoid collisions in the bucket/DB.
                      final originalName = picked.name;
                      final dotIndex = originalName.lastIndexOf('.');
                      final extension = dotIndex != -1 ? originalName.substring(dotIndex) : '';
                      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? 'anon'}$extension';

                      // Upload and capture the returned URL so we can store it in Firestore.
                      await uploader.uploadFile( // ! TODO DEAL WITH BIG FILES
                        fileBytes: bytes,
                        fileName: uniqueName,
                        onProgress: (progress) {
                          // setState(() {
                          //   _progress = progress;
                          // });
                        },
                      );

                      DocumentReference docId = await FirebaseFirestore.instance.collection('Posts').add({
                        'authorID': FirebaseAuth.instance.currentUser!.uid,
                        'postDate': DateTime.now(),
                        'likeCount': 0,
                        'caption': details,
                        'imageName': uniqueName,
                      });
                      await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).collection('Posts').doc(docId.id).set({});
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

Widget postTemplate(BuildContext context, Map postData, DocumentReference? favorited, postId) {
    final postDate = postData['postDate'].toDate();
    final minutesPassed = DateTime.now().difference(postDate).inMinutes;
    Future<Map> userData = getUser(postData['authorID']);
    final postRef = FirebaseFirestore.instance.collection('Posts').doc(postId.toString());
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Stack(
          children: [
            postData.containsKey('imageName') && postData['imageName'] != null
              ? Image.network(
                'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${postData['imageName']}',
                height: MediaQuery.sizeOf(context).width,
                width: MediaQuery.sizeOf(context).width,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return SizedBox(
                    height: MediaQuery.sizeOf(context).width,
                    width: MediaQuery.sizeOf(context).width,
                    child: Center(child: CircularProgressIndicator())
                  );
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
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading data'));
                } else if (snapshot.hasData) {
                  return GestureDetector(
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfilePage(uid: postData['authorID'], userData: snapshot.data!))
                      );
                    },
                    child: Row(
                      spacing: 5,
                      children: [
                        snapshot.data!['profilePictureUrl'] != null
                        ? CircleAvatar(
                          backgroundImage: NetworkImage(snapshot.data!['profilePictureUrl']),
                          radius: 15,
                        )
                        : Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(child: Icon(Icons.person)),
                        ),
                        Text(
                          snapshot.data!['displayName'],
                        ),
                      ],
                    ),
                  );
                } else {
                  return const Center(child: Text('No data available'));
                }
              },
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
                  SizedBox(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: currentUid == null ? const Stream.empty() : postRef.collection('Likes').doc(currentUid).snapshots(),
                      builder: (context, likeSnap) {
                        final hasLiked = likeSnap.hasData && likeSnap.data!.exists;
                        final likeCount = (postData['likeCount'] ?? 0) as int;
                        return GestureDetector(
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) {
                                return FutureBuilder<QuerySnapshot>(
                                  future: postRef.collection('Likes').orderBy('createdAt', descending: true).limit(50).get(),
                                  builder: (context, likesSnap) {
                                    if (likesSnap.connectionState == ConnectionState.waiting) {
                                      return SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                                    }
                                    if (!likesSnap.hasData || likesSnap.data!.docs.isEmpty) {
                                      return SizedBox(height: 200, child: Center(child: Text('No likes yet')));
                                    }
                                    final likeDocs = likesSnap.data!.docs;
                                    return SizedBox(
                                      height: 300,
                                      child: ListView(
                                        children: likeDocs.map((d) {
                                          final data = d.data() as Map<String, dynamic>;
                                          final name = data['displayName'] ?? data['userId'] ?? 'User';
                                          final photo = data['photoUrl'] as String?;
                                          return ListTile(
                                            leading: photo != null
                                              ? CircleAvatar(backgroundImage: NetworkImage(photo))
                                              : CircleAvatar(child: Icon(Icons.person)),
                                            title: Text(name),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                );
                              },
                            );

                          },

                          onTap: () async {
                            if (currentUid == null) {
                              // Not signed in: optionally navigate to sign-in
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
                          },
                          child: Row(
                            spacing: 5,
                            children: [
                              Icon(hasLiked ? Icons.favorite : Icons.favorite_border),
                              Text('$likeCount')
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    child: Row(
                      spacing: 5,
                      children: [
                        Icon(Icons.comment_outlined),
                        Text('0')
                      ],
                    )
                  ),
                  SizedBox(
                    child: Row(
                      spacing: 5,
                      children: [
                        Icon(Icons.send_outlined),
                        Text('2')
                      ],
                    )
                  )
                ],
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  child: Text(
                    postData['caption'],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  child: Text(
                    (minutesPassed~/60) ~/ 24 > 0
                      ? '${minutesPassed~/60 ~/ 24} days ago'
                      : minutesPassed~/60 >= 1
                        ? '${minutesPassed~/60} hours ago'
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
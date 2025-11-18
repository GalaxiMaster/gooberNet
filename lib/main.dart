import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudflare_r2_uploader/cloudflare_r2_uploader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:goober_net/settings.dart';
import 'package:goober_net/sign_in_page.dart';
import 'package:goober_net/upload_page.dart';
import 'package:image_picker/image_picker.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

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
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const AuthGate(),
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
final users = FirebaseFirestore.instance.collection('Posts');
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
                  children: docs.map((d) => postTemplate(context, d .data())).toList(),
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
                      await uploader.uploadFile(
                        fileBytes: bytes,
                        fileName: uniqueName,
                        onProgress: (progress) {
                          // setState(() {
                          //   _progress = progress;
                          // });
                        },
                      );

                      await FirebaseFirestore.instance.collection('Posts').add({
                        'postAuthor': FirebaseAuth.instance.currentUser?.displayName ?? FirebaseAuth.instance.currentUser!.email,
                        'postDate': DateTime.now(),
                        'caption': details,
                        'imageName': uniqueName,
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

  Widget postTemplate(BuildContext context, Map postData) {
    final postDate = postData['postDate'].toDate();
    final minutesPassed = DateTime.now().difference(postDate).inMinutes;

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
                  return Center(child: CircularProgressIndicator());
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
              child: Row(
                spacing: 5,
                children: [
                  FirebaseAuth.instance.currentUser!.photoURL != null
                  ? CircleAvatar(
                    backgroundImage: NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!),
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
                    postData['postAuthor'],
                  ),
                ],
              )
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
                    child: Row(
                      spacing: 5,
                      children: [
                        Icon(Icons.favorite_border),
                        Text('0')
                      ],
                    )
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
}
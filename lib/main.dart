import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
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
            ),
            body: ListView(
              children: docs.map((d) => postTemplate(context, d)).toList(),
            )
          );
      },
    );

  }

  Widget postTemplate(BuildContext context, QueryDocumentSnapshot<Map> postData) {
    final postDate = postData['postDate'].toDate();
    final hoursPassed = DateTime.now().difference(postDate).inHours;


    return Column(
      children: [
        Stack(
          children: [
            Container(
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
                  Container(
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
                    hoursPassed % 24 == 0
                      ? '${hoursPassed ~/ 24} days ago'
                      : hoursPassed < 1
                        ? 'Just now'
                        : '$hoursPassed hours ago',
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
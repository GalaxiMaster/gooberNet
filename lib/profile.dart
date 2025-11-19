import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  final String uid;
  final Map userData;
  const ProfilePage({super.key, required this.uid, required this.userData});
  @override
  // ignore: library_private_types_in_public_api
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  late final userPosts;
  final likes = FirebaseFirestore.instance.collection('Likes');

  @override
  initState() {
    super.initState();
    setUserCollection();
  }
  setUserCollection() async{
    userPosts = FirebaseFirestore.instance.collection('Users').doc(widget.uid).collection('Posts').orderBy('postDate', descending: true);

  }
  @override
  Widget build( context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Page'),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: userPosts.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final data = snapshot.data;
            if (data == null || data.docs.isEmpty) {
              return const Text('No posts found.');
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 15,
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundImage: NetworkImage(
                          widget.userData['profilePictureUrl']!,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom:10),
                        child: Text(
                          widget.userData['displayName']!,
                          style: const TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                    childAspectRatio: .75,
                  ),
                  itemCount: data.docs.length,
                  itemBuilder: (context, index) {
                    final doc = data.docs[index];
                    return FutureBuilder(
                      future: FirebaseFirestore.instance.collection('Posts').doc(doc.id).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return const Center(child: Text('Error loading data'));
                        } else if (snapshot.hasData) {
                          final post = snapshot.data!.data();
                          
                          return CachedNetworkImage(
                            imageUrl: 'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${post!['imageName']}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) {
                              return Center(child: CircularProgressIndicator());
                            },
                          );
                        } else {
                          return const Center(child: Text('No data'));
                        }
                      },
                    );
                  },
                ),
              ],
            );
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return const CircularProgressIndicator();
          }
        },
      )
    );
  }

}
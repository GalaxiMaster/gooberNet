import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goober_net/main.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
                Divider(height: 5, thickness: .5,),
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
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostPage(
                                    docs: data.docs,
                                    initialIndex: index,   // pass the index you want to scroll to
                                  ),
                                ),
                              );
                            },
                            onLongPress: (){
                              ImageOverlay.show(
                                context,
                                post['imageDetails'][0]
                              );
                            },
                            child: CachedNetworkImage(
                              imageUrl: 'https://pub-b665727283304785a65fc86be829fa67.r2.dev/${post!['imageDetails'][0]['imageId']}',
                              fit: BoxFit.cover,
                              placeholder: (context, url) {
                                return Center(child: CircularProgressIndicator());
                              },
                            ),
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


class PostPage extends StatefulWidget {
  final List<QueryDocumentSnapshot> docs;
  final int initialIndex;

  const PostPage({
    required this.docs,
    required this.initialIndex,
  });

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final ItemScrollController _scrollController = ItemScrollController();
  final likes = FirebaseFirestore.instance.collection('Likes');

  @override
  void initState() {
    super.initState();

    // Scroll immediately after the list is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.scrollTo(
        index: widget.initialIndex,
        duration: const Duration(milliseconds: 1),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScrollablePositionedList.builder(
        itemScrollController: _scrollController,
        itemCount: widget.docs.length,
        itemBuilder: (context, i) {
          return FutureBuilder(
            future: FirebaseFirestore.instance
                .collection('Posts')
                .doc(widget.docs[i].id)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return PostTemplate(
                postData: snapshot.data!.data()!,
                favorited: likes.doc(widget.docs[i].id),
                postId: widget.docs[i].id,
              );
            },
          );
        },
      ),
    );
  }
}

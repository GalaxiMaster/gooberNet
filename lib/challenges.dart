import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _ChallengesPageState createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  late Map<String, Map<String, dynamic>> userChallenges;


  Future<Map<String, Map<String, dynamic>>> getChallenges() async {
    QuerySnapshot<Map<String, dynamic>> allChallenges = await FirebaseFirestore.instance.collection('Challenges').get();

    QuerySnapshot<Map<String, dynamic>> userChallengesQuery = await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser!.uid).collection('JoinedChallenges').get();

    userChallenges = userChallengesQuery.docs.asMap().map((_, doc) {
      return MapEntry(
        doc.id,
        doc.data(),
      );
    });;

    return allChallenges.docs.asMap().map((_, doc) {
      return MapEntry(
        doc.id,
        doc.data(),
      );
    });
  }
  Duration getTimeRemaining(DateTime startTime, DateTime endTime) {
    DateTime now = DateTime.now();
    if (startTime.isBefore(now)){
      Duration difference = startTime.difference(now);
      return difference;
    } else {
      return Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
    future: getChallenges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading data'));
        } else if (snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (BuildContext context, int index) { 
                MapEntry challenge = snapshot.data!.entries.toList()[index];
                return Card(
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      color: Colors.grey.withValues(alpha: 0.1),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Builder( // TODO add ending soon
                                        builder: (context) {
                                          Duration timeTillStart = getTimeRemaining(challenge.value['startTime'].toDate(), challenge.value['endTime'].toDate());
                                          bool isActive = timeTillStart <= Duration.zero;
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.sunny, 
                                                size: 16, 
                                                color: isActive ? Colors.green : Color(0xFFFFD700),
                                              ),
                                              SizedBox(width: 5,),
                                              Text(
                                                 isActive
                                                  ? 'Active'
                                                  : 'Starting in ${timeTillStart.inDays} days'
                                              )
                                            ],
                                          );
                                        }
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8,),
                                  Text(
                                    challenge.value['name'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  Text(
                                    challenge.value['description'],
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  )
                                ],
                              ),
                            ),
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.deepPurpleAccent,
                                borderRadius: BorderRadius.circular(40)
                              ),
                              child: ClipOval(child: CachedNetworkImage(imageUrl: 'https://pbs.twimg.com/media/G95JshnWcAADzN2?format=jpg&name=large')),
                            )
                          ],
                        ),
                        SizedBox(height: 15),
                        if (!userChallenges.containsKey(challenge.key))
                        Align(
                          alignment: Alignment.bottomRight,
                          child: GestureDetector(
                            onTap: () {
                              // Join Challenge
                              FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser!.uid).collection('JoinedChallenges').doc(challenge.key).set({
                                'joinedAt': DateTime.now(),
                                // 'challengeRef': ''
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.teal.withBlue(200),
                                borderRadius: BorderRadius.circular(30)
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                child: Text(
                                  'Join',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                        )
                        else
                        Align(
                          alignment: Alignment.bottomRight,
                          child: GestureDetector(
                            onTap: () {
                              // Join Challenge
                              FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser!.uid).collection('JoinedChallenges').doc(challenge.key).delete();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(30)
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                child: Text(
                                  'Leave',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          return const Center(child: Text('No data available'));
        }
      },
    );
  }
}
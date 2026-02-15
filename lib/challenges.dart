import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goober_net/challenge_details.dart';
import 'package:goober_net/models.dart';
import 'package:goober_net/providers/challenge_repo_providers.dart';
import 'package:goober_net/utils.dart';
import 'package:google_fonts/google_fonts.dart';

class ChallengesPage extends ConsumerStatefulWidget {
  const ChallengesPage({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _ChallengesPageState createState() => _ChallengesPageState();
}

class _ChallengesPageState extends ConsumerState<ChallengesPage> with SingleTickerProviderStateMixin {
  Map<String, Map<String, dynamic>> userChallenges = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Duration getTimeRemaining(DateTime startTime) {
    DateTime now = DateTime.now();
    return startTime.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    final allChallengesAsync = ref.watch(
      globalChallengeProvider(FirebaseAuth.instance.currentUser!.uid),
    );
    final customChallengesAsync = ref.watch(
      userChallengesProvider(FirebaseAuth.instance.currentUser!.uid),
    );
    final globalJoinsAsync = ref.watch(
      globalJoinsProvider(FirebaseAuth.instance.currentUser!.uid),
    );
    
    return Column(
      children: [
        // TabBar
        Container(
          color: Colors.transparent,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.googleSansCode(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'ACTIVE'),
              Tab(text: 'COMPLETED'),
            ],
          ),
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveTab(allChallengesAsync, customChallengesAsync, globalJoinsAsync),
              _buildCompletedTab(allChallengesAsync, customChallengesAsync, globalJoinsAsync),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTab(
    AsyncValue<Map<String, Challenge>> allChallengesAsync,
    AsyncValue<Map<String, Challenge>> customChallengesAsync,
    AsyncValue<Map> globalJoinsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Global',
                style: GoogleFonts.googleSansCode(fontSize: 16),
              ),
            ),
            allChallengesAsync.when(
              data: (allChallenges) {
                // Filter out completed challenges
                final activeChallenges = Map.fromEntries(
                  allChallenges.entries.where((entry) {
                    final challenge = entry.value;
                    return challenge.progressCount.length < (challenge.data['maxProgress'] ?? challenge.progressTotal);
                  }),
                );
                
                if (activeChallenges.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No active global challenges',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: activeChallenges.length,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final challenge = activeChallenges.entries.toList()[index];
                    final String challengeId = challenge.key;
                    final Challenge data = challenge.value;

                    return globalJoinsAsync.maybeWhen(
                      data: (joinsData) {
                        bool isJoined = joinsData.containsKey(challenge.key);
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChallengeDetails(
                                data: data.toMap(),
                                challengeId: challenge.key,
                              ),
                            ),
                          ),
                          child: Card(
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Column(
                                children: [
                                  _buildHeader(data.toMap()),
                                  const SizedBox(height: 10),
                                  if (isJoined) _buildProgressBar(challenge.value),
                                  _buildActionButtons(challengeId, isJoined),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      orElse: () => SizedBox.shrink(),
                    );
                  },
                );
              },
              error: (error, trace) =>
                  Text('Failed to get data. Error: $error'),
              loading: () => CircularProgressIndicator(),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Custom',
                style: GoogleFonts.googleSansCode(fontSize: 16),
              ),
            ),
            customChallengesAsync.when(
              data: (customChallenges) {
                // Filter out completed challenges
                final activeChallenges = Map.fromEntries(
                  customChallenges.entries.where((entry) {
                    final challenge = entry.value;
                    return challenge.progressCount.length < (challenge.data['maxProgress'] ?? challenge.progressTotal);
                  }),
                );
                
                if (activeChallenges.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No active custom challenges',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: activeChallenges.length,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final challenge = activeChallenges.entries.toList()[index];
                    final Map data = challenge.value.toMap();

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChallengeDetails(
                            data: data,
                            challengeId: challenge.key,
                          ),
                        ),
                      ),
                      onLongPress: () {
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
                                    title: Text('Delete Challenge'),
                                    onTap: () async {
                                      User? currentUser = FirebaseAuth.instance.currentUser;
                                      if (currentUser == null) return;

                                      final repo = await ref.watch(repositoryProvider(currentUser.uid).future);
                                      await repo.deleteUserChallenge(challenge.key);
                                      
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Card(
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          data['description'],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildChallengeIcon(),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildProgressBar(challenge.value),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (error, trace) =>
                  Text('Failed to get data. Error: $error'),
              loading: () => CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTab(
    AsyncValue<Map<String, Challenge>> allChallengesAsync,
    AsyncValue<Map<String, Challenge>> customChallengesAsync,
    AsyncValue<Map> globalJoinsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Global',
                style: GoogleFonts.googleSansCode(fontSize: 16),
              ),
            ),
            allChallengesAsync.when(
              data: (allChallenges) {
                // Filter only completed challenges
                final completedChallenges = Map.fromEntries(
                  allChallenges.entries.where((entry) {
                    final challenge = entry.value;
                    return challenge.progressCount.length >= (challenge.data['maxProgress'] ?? challenge.progressTotal);
                  }),
                );
                
                if (completedChallenges.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 64,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No completed global challenges yet',
                            style: GoogleFonts.googleSansCode(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: completedChallenges.length,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final challenge = completedChallenges.entries.toList()[index];
                    // final String challengeId = challenge.key;
                    final Challenge data = challenge.value;

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChallengeDetails(
                            data: data.toMap(),
                            challengeId: challenge.key,
                          ),
                        ),
                      ),
                      child: Card(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.green.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data.data['name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Completed',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildChallengeIcon(),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildProgressBar(challenge.value),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (error, trace) =>
                  Text('Failed to get data. Error: $error'),
              loading: () => CircularProgressIndicator(),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Custom',
                style: GoogleFonts.googleSansCode(fontSize: 16),
              ),
            ),
            customChallengesAsync.when(
              data: (customChallenges) {
                // Filter only completed challenges
                final completedChallenges = Map.fromEntries(
                  customChallenges.entries.where((entry) {
                    final challenge = entry.value;
                    return challenge.progressCount.length >= (challenge.data['maxProgress'] ?? challenge.progressTotal);
                  }),
                );
                
                if (completedChallenges.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 64,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No completed custom challenges yet',
                            style: GoogleFonts.googleSansCode(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: completedChallenges.length,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final challenge = completedChallenges.entries.toList()[index];
                    final Map data = challenge.value.toMap();

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChallengeDetails(
                            data: data,
                            challengeId: challenge.key,
                          ),
                        ),
                      ),
                      child: Card(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.green.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Completed',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildChallengeIcon(),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildProgressBar(challenge.value),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (error, trace) =>
                  Text('Failed to get data. Error: $error'),
              loading: () => CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map data) {
    Duration timeTillStart = getTimeRemaining(parseDate(data['startTime']));
    bool isActive = timeTillStart <= Duration.zero;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sunny,
                      size: 16,
                      color: isActive ? Colors.green : const Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive
                          ? 'Active'
                          : 'Starting in ${timeTillStart.inDays} days',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                data['description'],
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
        _buildChallengeIcon(),
      ],
    );
  }

  Widget _buildProgressBar(Challenge progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${progress.progressCount.length}/${progress.data['maxProgress'] ?? progress.progressTotal}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.progressCount.length/(progress.data['maxProgress'] ?? progress.progressTotal),
          borderRadius: BorderRadius.circular(40),
          minHeight: 12,
          backgroundColor: const Color.fromARGB(255, 59, 65, 77),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildActionButtons(String id, bool isJoined) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onTap: () {
          final docRef = FirebaseFirestore.instance
              .collection('Users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('JoinedChallenges')
              .doc(id);

          setState(() {
            if (isJoined) {
              docRef.delete();
              userChallenges.remove(id);
            } else {
              final newData = {'joinedAt': DateTime.now()};
              docRef.set(newData);
              userChallenges[id] = newData;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: isJoined ? Colors.redAccent : Theme.of(context).colorScheme.primary.withBlue(200),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            isJoined ? 'Leave' : 'Join',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeIcon() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent,
        borderRadius: BorderRadius.circular(40),
        image: DecorationImage(
          image: AssetImage('assets/images/color-hunt-header.jpg'),
        ),
      ),
    );
  }
}
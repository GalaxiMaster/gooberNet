import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:goober_net/utils.dart';
import 'package:goober_net/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _ChallengesPageState createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  // 1. Store the Future to prevent re-triggering on every rebuild
  late Future<Map<String, Map<String, dynamic>>> _challengesFuture;
  
  // 2. Local state for quick UI updates
  Map<String, Map<String, dynamic>> userChallenges = {};
  final Map<String, List<int>> _progressCache = {};

  @override
  void initState() {
    super.initState();
    _challengesFuture = _loadAllData();
  }

  Future<Map<String, Map<String, dynamic>>> _loadAllData() async {
    QuerySnapshot<Map<String, dynamic>> allChallenges = await FirebaseFirestore.instance.collection('Challenges').get();

    QuerySnapshot<Map<String, dynamic>> userChallengesQuery = await FirebaseFirestore.instance.collection('Users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('JoinedChallenges').get();

    userChallenges = userChallengesQuery.docs.asMap().map((_, doc) {
      return MapEntry(doc.id, doc.data());
    });

    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;

    for (var doc in allChallenges.docs) {
      String challengeName = doc.data()['name'] ?? "";
      int count = 0;
      for (int i = 0; i < 9; i++) {
        final file = File('$path/challenge_$challengeName$i.png');
        if (await file.exists()) count++;
      }
      _progressCache[challengeName] = [count, 9];
    }

    return allChallenges.docs.asMap().map((_, doc) => MapEntry(doc.id, doc.data()));
  }

  Duration getTimeRemaining(DateTime startTime) {
    DateTime now = DateTime.now();
    return startTime.difference(now);
  }

  void _refreshData() {
    setState(() {
      _challengesFuture = _loadAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _challengesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading challenges'));
        }

        final challenges = snapshot.data!.entries.toList();

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Global',
                  style: GoogleFonts.googleSansCode(
                    fontSize: 16,
                  ),
                ),
              ),
              ListView.builder(
                itemCount: challenges.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final challenge = challenges[index];
                  final String challengeId = challenge.key;
                  final Map data = challenge.value;
                  final bool isJoined = userChallenges.containsKey(challengeId);
              
                  return GestureDetector(
                    onTap: () async {
                      // Wait for the user to return and then refresh the progress icons
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ChallengeDetails(data: data)),
                      );
                      _refreshData();
                    },
                    child: Card(
                      color: Colors.grey.withValues(alpha: 0.2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          children: [
                            _buildHeader(data),
                            const SizedBox(height: 10),
                            
                            // Show Progress bar ONLY if joined, using cached data
                            if (isJoined) _buildProgressBar(data['name']),
              
                            _buildActionButtons(challengeId, isJoined),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Custom',
                  style: GoogleFonts.googleSansCode(
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Map data) {
    Duration timeTillStart = getTimeRemaining(data['startTime'].toDate());
    bool isActive = timeTillStart <= Duration.zero;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sunny, size: 16, color: isActive ? Colors.green : const Color(0xFFFFD700)),
                    const SizedBox(width: 5),
                    Text(isActive ? 'Active' : 'Starting in ${timeTillStart.inDays} days'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(data['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(data['description'], overflow: TextOverflow.ellipsis, maxLines: 2),
            ],
          ),  
        ),
        _buildChallengeIcon(),
      ],
    );
  }

  Widget _buildProgressBar(String name) {
    final progress = _progressCache[name] ?? [0, 9];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${progress[0]}/${progress[1]}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress[0] / progress[1],
          borderRadius: BorderRadius.circular(40),
          minHeight: 12,
          backgroundColor: const Color.fromARGB(255, 40, 44, 52),
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
            color: isJoined ? Colors.redAccent : Colors.teal.withBlue(200),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(isJoined ? 'Leave' : 'Join', style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildChallengeIcon() {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(color: Colors.deepPurpleAccent, borderRadius: BorderRadius.circular(40)),
      child: ClipOval(child: CachedNetworkImage(imageUrl: 'https://pbs.twimg.com/media/G95JshnWcAADzN2?format=jpg&name=large')),
    );
  }
}

class ChallengeDetails extends StatefulWidget {
  final Map data;
  const ChallengeDetails({super.key, required this.data});
  @override
  // ignore: library_private_types_in_public_api
  _ChallengeDetailsState createState() => _ChallengeDetailsState();
}

class _ChallengeDetailsState extends State<ChallengeDetails> {
  Map<int, String> selectedImages = {};

  // Save image to disk
  Future<void> _persistImage(int index, Uint8List bytes) async {
    final path = await localPath;
    final file = File('$path/challenge_${widget.data['name']}$index.png');
    await file.writeAsBytes(bytes);
  }

  // Load all saved images from disk
  Future<void> _loadSavedImages() async {
    final path = await localPath;
    final Map<int, String> loaded = {};

    for (int i = 0; i < 9; i++) {
      final file = File('$path/challenge_${widget.data['name']}$i.png');
      if (await file.exists()) {
        loaded[i] = file.path;
      }
    }
    if (!mounted) return;

    setState(() {
      selectedImages = loaded;
    });
  }
  @override
  initState(){
    super.initState();
    _loadSavedImages();
    Future.microtask(() {
      if (!mounted) return;
      precacheImage(
        const AssetImage('assets/images/color-hunt-header.jpg'),
        context,
      );
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderImage(header: widget.data['name']),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Color target: ',
                        style: TextStyle(
                          fontSize: 18
                        ),
                      ),
                      Text(
                        widget.data['target']['colorName'],
                        style: GoogleFonts.vt323(
                          color: hexToColor(widget.data['target']['hexApprox']),
                          fontSize: 22,
                          fontWeight: FontWeight.bold
                        ),
                      )
                    ],
                  ),
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: hexToColor(widget.data['target']['hexApprox']),
                      borderRadius: BorderRadius.circular(5)
                    ),
                  ),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2.5,
                      mainAxisSpacing: 2.5,
                      childAspectRatio: 1.0, // forces squares
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                  
                          final res = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 100, // optional compression
                          );
                          if (res != null){
                            final fileSize = await res.length(); // in bytes

                            const maxSize = 5 * 1024 * 1024; // 5 MB limit
                            if (fileSize > maxSize){
                              if (context.mounted){
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("File too large. Maximum allowed is 5MB."),
                                    ),
                                  );    
                                }
                                return;
                            }
                            Uint8List imageAsBytes = await res.readAsBytes();
                            String imagePath = res.path;

                            setState(() {
                              selectedImages[index] = imagePath;
                            });
                            await _persistImage(index, imageAsBytes);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2.5),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.blueGrey),
                            child: selectedImages.containsKey(index) 
                              ? Image.file(
                                fit: BoxFit.cover,
                                // width: width, 
                                // height: height, 
                                File(selectedImages[index]!),
                                gaplessPlayback: true,
                                cacheWidth: 512,
                              ) 
                              : Icon(Icons.upload),
                          ),
                        ),
                      );
                    },
                    shrinkWrap: true,
                  ),
                  Row(
                    spacing: 16,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 40, 44, 52), 
                          borderRadius: BorderRadius.circular(40)
                        ),
                        child: TextButton.icon(
                          onPressed: () async {
                            LoadingOverlay loadingOverlay = LoadingOverlay();
                            loadingOverlay.showLoadingOverlay(context);
                            File file = await createNineImageCollageCanvas(images: selectedImages.values.toList());
                            loadingOverlay.removeLoadingOverlay();
                            if (await file.exists()) {
                              if (!context.mounted) return;
                              postAndUpload([XFile(file.path)], context);
                            }
                          }, 
                          label: Text(
                            'Post',
                            style: TextStyle(
                              color: Colors.white
                            ),
                          ),
                          icon: Icon(Icons.post_add),
                          iconAlignment: IconAlignment.end,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 40, 44, 52), 
                          borderRadius: BorderRadius.circular(40)
                        ),
                        child: TextButton.icon(
                          onPressed: () async {
                            LoadingOverlay loadingOverlay = LoadingOverlay();
                            loadingOverlay.showLoadingOverlay(context);
                            File file = await createNineImageCollageCanvas(images: selectedImages.values.toList());
                            if (await file.exists()) {
                              await SharePlus.instance.share(
                                ShareParams(
                                  files: [XFile(file.path)],
                                  previewThumbnail: XFile(file.path),
                                  text: 'Your canvas',
                                ),
                              );
                            }
                            loadingOverlay.removeLoadingOverlay();
                          }, 
                          label: Text(
                            'Share',
                            style: TextStyle(
                              color: Colors.white
                            ),
                          ),
                          icon: Icon(Icons.share),
                          iconAlignment: IconAlignment.end,
                        ),
                      )
                    ],
                  ),
                ],
              ),
            )
          ),
        ],
      )
    );
  }
}

class _HeaderImage extends StatelessWidget {
  final String header;
  static const _headerImage = AssetImage('assets/images/color-hunt-header.jpg');

  const _HeaderImage({required this.header});
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: _headerImage,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color.fromARGB(255, 0, 20, 20),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 5,
          left: 15,
          child: Stack(
            children: [
              Text(
                header,
                style: GoogleFonts.vt323(
                  fontSize: 27,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.5
                    ..color = Colors.black,
                ),
              ),
              Text(
                header,
                style: GoogleFonts.vt323(
                  fontSize: 27,
                  color: Colors.white,
                ),
              ),
            ],
          )
        ),
      ],
    );
  }
}

Future<File> createNineImageCollageCanvas({
  required List<String> images,
  int tileSize = 512,
  double borderRadius = 15,
  double spacing = 6,
}) async {
  final int canvasSize = ((tileSize * 3) + (spacing * 2)).toInt();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // 1. Draw Background (optional)
  final Paint backgroundPaint = Paint()..color = Colors.transparent;
  canvas.drawRect(Rect.fromLTWH(0, 0, canvasSize.toDouble(), canvasSize.toDouble()), backgroundPaint);

  for (int i = 0; i < images.length; i++) {
    // Decode image into a GPU-friendly ui.Image
    final ui.Codec codec = await ui.instantiateImageCodec(await File(images[i]).readAsBytes());
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image uiImg = frame.image;

    final int row = i ~/ 3;
    final int col = i % 3;
    
    // Calculate position
    final double x = col * (tileSize + spacing);
    final double y = row * (tileSize + spacing);
    final Rect destRect = Rect.fromLTWH(x, y, tileSize.toDouble(), tileSize.toDouble());

    // 2. Create the Rounded Clip
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(destRect, Radius.circular(borderRadius)));

    // 3. Draw the image into the clipped area (Center Crop logic)
    _paintCenterCrop(canvas, uiImg, destRect);
    
    canvas.restore();
  }

  // Convert Canvas to Image
  final ui.Image finalImage = await recorder.endRecording().toImage(canvasSize, canvasSize);
  final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
  
  // Save to file
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/collage_myCollage.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  
  return file;
}

void _paintCenterCrop(Canvas canvas, ui.Image image, Rect destRect) {
  final double srcWidth = image.width.toDouble();
  final double srcHeight = image.height.toDouble();
  final double side = srcWidth < srcHeight ? srcWidth : srcHeight;

  final Rect srcRect = Rect.fromLTWH(
    (srcWidth - side) / 2,
    (srcHeight - side) / 2,
    side,
    side,
  );

  canvas.drawImageRect(image, srcRect, destRect, Paint()..filterQuality = FilterQuality.high);
}

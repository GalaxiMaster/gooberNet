import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

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
    });

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
                return GestureDetector(
                  onTap: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ChallengeDetails(data: challenge.value,))
                    );
                  },
                  child: Card(
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
                                Map<String, dynamic> data = {
                                  'joinedAt': DateTime.now(),
                                  // 'challengeRef': ''
                                };
                                FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser!.uid).collection('JoinedChallenges').doc(challenge.key).set(data);
                                
                                setState(() {
                                  userChallenges[challenge.key] = data;
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
                              onTap: () { // TODO add confirmation popup
                                // Join Challenge
                                FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser!.uid).collection('JoinedChallenges').doc(challenge.key).delete();
                                
                                setState(() {
                                  userChallenges.remove(challenge.key);
                                });
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

class ChallengeDetails extends StatefulWidget {
  final Map data;
  const ChallengeDetails({super.key, required this.data});
  @override
  // ignore: library_private_types_in_public_api
  _ChallengeDetailsState createState() => _ChallengeDetailsState();
}

class _ChallengeDetailsState extends State<ChallengeDetails> {
  Map<int, Uint8List> selectedImages = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderImage(header: widget.data['name'],),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GridView.builder(
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
                        imageQuality: 90, // optional compression
                      );
                      if (res != null){
                        Uint8List imageAsBytes = await res.readAsBytes();
                        setState(() {
                          selectedImages[index] = imageAsBytes;
                        });
                        if (selectedImages.length == 9){
                          createNineImageCollageCanvas(images: selectedImages.values.toList());
                        }
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2.5),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.blueGrey),
                        child: selectedImages.containsKey(index) 
                          ? Image.memory(
                            // width: width, 
                            // height: height, 
                            selectedImages[index]!
                          ) 
                          : Icon(Icons.upload),
                      ),
                    ),
                  );
                },
                shrinkWrap: true,
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

  const _HeaderImage({required this.header});
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          'https://pbs.twimg.com/media/G95JshnWcAADzN2?format=jpg&name=large',
          fit: BoxFit.cover,
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
  required List<Uint8List> images,
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
    final ui.Codec codec = await ui.instantiateImageCodec(images[i]);
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
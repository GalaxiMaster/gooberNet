import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goober_net/providers.dart';
import 'package:goober_net/utils.dart';
import 'package:goober_net/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ChallengeDetails extends ConsumerStatefulWidget {
  final Map data;
  final String challengeId;
  const ChallengeDetails({
    super.key,
    required this.data,
    required this.challengeId,
  });
  @override
  // ignore: library_private_types_in_public_api
  _ChallengeDetailsState createState() => _ChallengeDetailsState();
}

class _ChallengeDetailsState extends ConsumerState<ChallengeDetails> {
  Map<int, String> selectedImages = {};


  // Save image to disk
  Future<void> _persistImage(int index, Uint8List bytes) async {
    final path = await localPath;
    final file = File('$path/challenge_${widget.challengeId}$index.png');
    await file.writeAsBytes(bytes);
  }
  // Remove image from disk
  Future<void> _deleteImage(int index, String filePath) async {
    final file = File(filePath);
    await file.delete();
  }
  // Load all saved images from disk
  Future<void> _loadSavedImages() async {
    final path = await localPath;
    final Map<int, String> loaded = {};

    for (int i = 0; i <( widget.data['maxProgress'] ?? 9); i++) {
      final file = File('$path/challenge_${widget.challengeId}$i.png');
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
  initState() {
    super.initState();
    _loadSavedImages();
    Future.microtask(() {
      if (!mounted) return;
      precacheImage(
        const AssetImage('assets/images/color-hunt-header.jpg'),
        size: Size(MediaQuery.sizeOf(context).width/(2/3), 100),
        context,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    int rows = int.tryParse(
      (widget.data['gridSize'] ?? "3x3")
          .toLowerCase()
          .split('x')
          .first,
    ) ?? 3;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color.fromARGB(255, 0, 20, 20),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderImage(header: widget.data['name']),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    color: Colors.grey.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.palette,
                                  color: hexToColor(widget.data['target']['hexApprox']),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      'Color: ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    Text(
                                      widget.data['target']['colorName'],
                                      style: GoogleFonts.vt323(
                                        color: hexToColor(widget.data['target']['hexApprox']),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 35,
                            decoration: BoxDecoration(
                              color: hexToColor(widget.data['target']['hexApprox']),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: hexToColor(widget.data['target']['hexApprox']).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: .5,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Collection',
                        style: GoogleFonts.googleSansCode(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 500),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selectedImages.length/widget.data['maxProgress'] >= 1 ? Colors.green : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${selectedImages.length}/${widget.data['maxProgress']}',
                          style: GoogleFonts.googleSansCode(
                            color: selectedImages.length/widget.data['maxProgress'] >= 1 ? Colors.white : Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: EdgeInsets.only(top: 10),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: rows,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    itemCount: widget.data['maxProgress'],
                    itemBuilder: (context, index) {
   
                      return GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final res = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 100,
                          );
                          if (res != null) {
                            final fileSize = await res.length();
                            const maxSize = 5 * 1024 * 1024;
                            if (fileSize > maxSize) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "File too large. Maximum allowed is 5MB.",
                                    ),
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
                  
                            final repo = await ref.watch(
                              repositoryProvider(
                                FirebaseAuth.instance.currentUser!.uid,
                              ).future,
                            );
                            await repo.recordImageAdded(
                              widget.challengeId,
                              index,
                            );
                            await _persistImage(index, imageAsBytes);
                          }
                        },
                        onLongPress: () async {
                          if (selectedImages[index] != null) {
                            _deleteImage(index, selectedImages[index]!);
                            final repo = await ref.watch(
                              repositoryProvider(
                                FirebaseAuth.instance.currentUser!.uid,
                              ).future,
                            );
                            await repo.recordImageRemoved(
                              widget.challengeId,
                              index,
                            );
                            setState(() {
                              selectedImages.remove(index);
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: selectedImages.containsKey(index)
                                ? Colors.transparent
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: selectedImages.containsKey(index)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final pixelRatio = MediaQuery.of(context).devicePixelRatio;
                                          final size = (constraints.maxWidth * pixelRatio*2).round();
                                          
                                          return Image(
                                            image: ResizeImage(
                                              FileImage(File(selectedImages[index]!)),
                                              width: size,
                                              height: size,
                                              policy: ResizeImagePolicy.fit,
                                            ),
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                          );
                                        },
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.1),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.grey[600],
                                  size: 32,
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: selectedImages.isEmpty
                              ? null
                              : () async {
                                  List<int> gridSize;
                                  try {
                                    gridSize = List<int>.from(
                                      (widget.data['gridSize'] ?? "3x3")
                                          .toLowerCase()
                                          .split('x')
                                          .map(int.parse)
                                          .toList(),
                                    );
                                    if (gridSize.length != 2) {
                                      throw Exception("Grid size invalid");
                                    }
                                  } catch (e) {
                                    debugPrint('invalid grid size $e');
                                    return;
                                  }
                                  LoadingOverlay loadingOverlay = LoadingOverlay();
                                  loadingOverlay.showLoadingOverlay(context);
                                  File file = await createImageCollageCanvas(
                                    images: selectedImages,
                                    gridSize: gridSize,
                                  );
                                  loadingOverlay.removeLoadingOverlay();
                                  if (await file.exists()) {
                                    if (!context.mounted) return;
                                    postAndUpload([XFile(file.path)], context);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 40, 44, 52),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.post_add),
                          label: const Text(
                            'Post',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: selectedImages.isEmpty
                              ? null
                              : () async {
                                  List<int> gridSize;
                                  try {
                                    gridSize = List<int>.from(
                                      (widget.data['gridSize'] ?? "3x3")
                                          .toLowerCase()
                                          .split('x')
                                          .map(int.parse)
                                          .toList(),
                                    );
                                    if (gridSize.length != 2) {
                                      throw Exception("Grid size invalid");
                                    }
                                  } catch (e) {
                                    debugPrint('invalid grid size $e');
                                    return;
                                  }
              
                                  LoadingOverlay loadingOverlay = LoadingOverlay();
                                  loadingOverlay.showLoadingOverlay(context);
                                  File file = await createImageCollageCanvas(
                                    images: selectedImages,
                                    gridSize: gridSize,
                                  );
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'Share',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildProgressIndicator() {
  //   int current = selectedImages.length;
  //   int total = widget.data['maxProgress'] ?? 9;
  //   double progress = current / total;
    
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text(
  //             'Progress',
  //             style: TextStyle(
  //               fontSize: 14,
  //               color: Colors.grey[400],
  //             ),
  //           ),
  //           Text(
  //             '${(progress * 100).toStringAsFixed(0)}%',
  //             style: GoogleFonts.googleSansCode(
  //               fontSize: 14,
  //               fontWeight: FontWeight.w600,
  //               color: Theme.of(context).colorScheme.primary,
  //             ),
  //           ),
  //         ],
  //       ),
  //       const SizedBox(height: 8),
  //       ClipRRect(
  //         borderRadius: BorderRadius.circular(8),
  //         child: LinearProgressIndicator(
  //           value: progress,
  //           minHeight: 8,
  //           backgroundColor: const Color.fromARGB(255, 59, 65, 77),
  //           valueColor: AlwaysStoppedAnimation<Color>(
  //             progress == 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
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
            image: DecorationImage(image: _headerImage, fit: BoxFit.cover),
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
                colors: [Colors.transparent, Color.fromARGB(255, 0, 20, 20)],
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
                style: GoogleFonts.vt323(fontSize: 27, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<File> createImageCollageCanvas({
  required Map<int, String> images,
  List<int> gridSize = const [3, 3],
  int tileSize = 512,
  double borderRadius = 15,
  double spacing = 6,
}) async {
  int rows = gridSize[0];
  int columns = gridSize[1];
  final int canvasSize = ((tileSize * rows) + (spacing * 2)).toInt();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Draw Background (optional)
  final Paint backgroundPaint = Paint()..color = Colors.transparent;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, canvasSize.toDouble(), canvasSize.toDouble()),
    backgroundPaint,
  );

  for (int i = 0; i < rows * columns; i++) {
    // Decode image into a GPU-friendly ui.Image
    if (!images.containsKey(i)) continue;
    final ui.Codec codec = await ui.instantiateImageCodec(
      await File(images[i]!).readAsBytes(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image uiImg = frame.image;

    final int row = i ~/ rows;
    final int col = i % columns;

    // Calculate position
    final double x = col * (tileSize + spacing);
    final double y = row * (tileSize + spacing);
    final Rect destRect = Rect.fromLTWH(
      x,
      y,
      tileSize.toDouble(),
      tileSize.toDouble(),
    );

    // Create the Rounded Clip
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(destRect, Radius.circular(borderRadius)),
    );

    // Draw the image into the clipped area (Center Crop logic)
    _paintCenterCrop(canvas, uiImg, destRect);

    canvas.restore();
  }

  // Convert Canvas to Image
  final ui.Image finalImage = await recorder.endRecording().toImage(
    canvasSize,
    canvasSize,
  );
  final ByteData? byteData = await finalImage.toByteData(
    format: ui.ImageByteFormat.png,
  );

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

  canvas.drawImageRect(
    image,
    srcRect,
    destRect,
    Paint()..filterQuality = FilterQuality.high,
  );
}
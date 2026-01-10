import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudflare_r2_uploader/cloudflare_r2_uploader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:goober_net/main.dart';
import 'package:goober_net/upload_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void postAndUpload(List<XFile> picked, BuildContext context) async { // TODO breakup function. also currently assumes files are within limits
  final details = await Navigator.push(
    // ignore: use_build_context_synchronously
    context,
    MaterialPageRoute(builder: (context) => UploadPage(imagePath: picked.map((p)=>p.path).toList())),
  );
  if (details == null) return;
  List<Map> imageUIDs = [];
  for (XFile image in picked){
    final bytes = await image.readAsBytes();
    final uploader = CloudflareR2Uploader(
      accountId: dotenv.get('accountId'), 
      accessKeyId: dotenv.get('accessKeyId'), 
      secretAccessKey: dotenv.get('secretAccessKey'), 
      bucketName: 'images'
    );
    // Build a unique filename to avoid collisions in the bucket/DB.
    final originalName = image.name;
    final dotIndex = originalName.lastIndexOf('.');
    final extension = dotIndex != -1 ? originalName.substring(dotIndex) : '';
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? 'anon'}$extension';
    Map imageSize = await getImageSize(image);
    imageUIDs.add({
      'imageId': uniqueName,
      'width': imageSize['width'],
      'height': imageSize['height'],
    });
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
  }

  final now = DateTime.now();
  DocumentReference docId = await FirebaseFirestore.instance.collection('Posts').add({
    'authorID': FirebaseAuth.instance.currentUser!.uid,
    'postDate': now,
    'likeCount': 0,
    'caption': details,
    'imageDetails': imageUIDs,
  });
  await FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).collection('Posts').doc(docId.id).set({
    'postDate': now,
  });
}


// Helper to get the local path
Future<String> get localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex'; // add full opacity
  }
  return Color(int.parse(hex, radix: 16));
}

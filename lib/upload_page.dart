import 'dart:io';

import 'package:flutter/material.dart';

class UploadPage extends StatefulWidget {
  final String imagePath;
  const UploadPage({super.key, required this.imagePath});
  @override
  // ignore: library_private_types_in_public_api
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  TextEditingController captionController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Center(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).width*0.7,
                  width: MediaQuery.sizeOf(context).width*0.7,
                  child: Image.file(File(widget.imagePath))
                ),
              ),
              Divider(),
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  hintText: 'Write a caption...'
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: (){
                Navigator.pop(context, captionController.text);
              },
              child: const Icon(Icons.check),
            ),
          )
        ],
      )
    );
  }

}
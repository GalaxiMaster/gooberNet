import 'dart:io';

import 'package:flutter/material.dart';

class UploadPage extends StatefulWidget {
  final List<String> imagePath;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                Center(
                  child: widget.imagePath.length == 1 
                    ? SizedBox(
                      height: MediaQuery.sizeOf(context).width*0.6,
                      width: MediaQuery.sizeOf(context).width*0.6,
                      child: Image.file(File(widget.imagePath[0]))
                    )
                    : SizedBox(
                      height: MediaQuery.sizeOf(context).width*0.6,
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).width * 0.6,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.imagePath.length,
                          itemBuilder: (context, index) {
                            return Image.file(
                              File(widget.imagePath[index]),
                              height: MediaQuery.sizeOf(context).width * 0.6,
                            );
                          },
                          separatorBuilder: (context, index) => const SizedBox(width: 5),
                        ),
                      )
                    )
                ),
                TextField(
                  controller: captionController,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: 'Add a caption...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 15
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                )
            
              ],
            ),
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
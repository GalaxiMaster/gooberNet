import 'package:flutter/material.dart';

class CreateChallenge extends StatefulWidget {
  const CreateChallenge({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _CreateChallengeState createState() => _CreateChallengeState();
}

class _CreateChallengeState extends State<CreateChallenge> {
  TextEditingController captionController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
      ),
      body: Stack(
        children: [

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
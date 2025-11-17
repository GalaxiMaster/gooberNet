import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R2 Image Upload (Worker)',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thingy'),
      ),
      body: Column(
        children: [
          Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: MediaQuery.sizeOf(context).width,
                    width: MediaQuery.sizeOf(context).width,
                    color: Colors.grey.shade700,
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Row(
                      spacing: 5,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(child: Icon(Icons.person)),
                        ),
                        Text(
                          'Author'
                        ),
                      ],
                    )
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      spacing: 20,
                      children: [
                        SizedBox(
                          child: Row(
                            spacing: 5,
                            children: [
                              Icon(Icons.favorite_border),
                              Text('0')
                            ],
                          )
                        ),
                        SizedBox(
                          child: Row(
                            spacing: 5,
                            children: [
                              Icon(Icons.comment_outlined),
                              Text('0')
                            ],
                          )
                        ),
                        SizedBox(
                          child: Row(
                            spacing: 5,
                            children: [
                              Icon(Icons.send_outlined),
                              Text('2')
                            ],
                          )
                        )
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                        child: Text(
                          '3 days ago',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      )
    );
  }

}

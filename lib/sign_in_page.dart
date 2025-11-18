import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  // ignore: library_private_types_in_public_api
  SignInPageState createState() => SignInPageState();
}

class SignInPageState extends State<SignInPage> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  @override
  void initState() {
    super.initState();

    // Initialize the plugin with your Web client ID for ID tokens.
    // This mirrors the example from the docs. Replace with your own
    // server/client ID if needed.
    GoogleSignIn.instance.initialize(
      serverClientId: dotenv.get('serverClientId'),
    ).then((_) {
      _authSub = GoogleSignIn.instance.authenticationEvents.listen(
        (event) async {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            final GoogleSignInAccount user = event.user;
            try {
              // The API surface for the plugin exposes a synchronous
              // `authentication` object on the account in this version.
              final GoogleSignInAuthentication authentication =
                  user.authentication;

              final credential = GoogleAuthProvider.credential(
                idToken: authentication.idToken,
              );

              await FirebaseAuth.instance.signInWithCredential(credential);
              debugPrint('Firebase sign-in complete for ${user.email}');
              if (mounted){
                Navigator.pushReplacementNamed(context, '/home');
              }
            } catch (e, st) {
              debugPrint('Error handling authentication event: $e');
              debugPrint('$st');
            }
          }
        },
        onError: (e) => debugPrint('Authentication event error: $e'),
      );
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Initialize with the web/server client ID (id token verification)
              await GoogleSignIn.instance.initialize(
                serverClientId: dotenv.get('serverClientId'),
              );

              // Trigger the (platform) authentication flow. The plugin will
              // deliver the resulting account via the authenticationEvents
              // stream handled in initState above.
              await GoogleSignIn.instance.authenticate();
            } on GoogleSignInException catch (e) {
              // The plugin exposes canceled/failure codes — log for debugging.
              debugPrint('Error signing in with Google: ${e.code} ${e.description}');
            } catch (e, st) {
              debugPrint('Unexpected error signing in with Google: $e');
              debugPrint('$st');
            }
          },
          child: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
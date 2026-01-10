/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
// const {onRequest} = require("firebase-functions/https");
// const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });


const {onDocumentCreated} = require("firebase-functions/v2/firestore");
admin.initializeApp();

exports.onPostCreated = onDocumentCreated(
    {
      region: "australia-southeast1",
      document: "Posts/{postId}",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return null;

      const post = snapshot.data();
      const authorId = post.authorID;
      const postId = event.params.postId;

      let authorName = "Someone"; // Default name if document doesn't exist
      const userSnap = await admin.firestore().doc(`Users/${authorId}`).get();
      if (userSnap.exists) {
        authorName = userSnap.data().displayName || "Someone";
      }
      const topic = `user_followers_${authorId}`;

      try {
        await admin.messaging().send({
          topic: topic,
          notification: {
            title: "New post",
            body: `${authorName} just shared a new post.`,
          },
          data: {
            postId: postId,
            authorId: authorId,
          },
        });
        console.log(`Sending to topic: ${topic}`);
        console.log(`Notification sent for post: ${postId}`);
      } catch (error) {
        console.error("Error sending message:", error);
      }
    });

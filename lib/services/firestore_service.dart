import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Generic method to add data
  Future<void> addDocument(String collection, Map<String, dynamic> data) async {
    await _db.collection(collection).add(data);
  }

  // Generic method to fetch data as a Stream (Great for real-time updates)
  Stream<List<Map<String, dynamic>>> getCollectionStream(String collection) {
    return _db.collection(collection).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc.data()).toList());
  }
}
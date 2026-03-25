import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new post (notice or schedule)
  Future<String> createPost({
    required String title,
    required String content,
    required Department department,
    required String year,
    required PostType type,
    required String createdBy,
  }) async {
    try {
      final docRef = _firestore.collection('posts').doc();
      
      final post = PostModel(
        id: docRef.id,
        title: title,
        content: content,
        department: department,
        year: year,
        type: type,
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await docRef.set(post.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Update an existing post
  Future<void> updatePost({
    required String postId,
    required String title,
    required String content,
    required String year,
  }) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'title': title,
        'content': content,
        'year': year,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  // Get posts for a specific department and user role
  Stream<List<PostModel>> getPostsForUser({
    required Department department,
    required int? year,
    PostType? type,
  }) {
    try {
      Query query = _firestore
          .collection('posts')
          .where('department', isEqualTo: department.name)
          .orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((post) => post.year == "all" || (year != null && post.year == year.toString()))
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to get posts: $e');
    }
  }

  // Get all posts for admin (can see all years in their department)
  Stream<List<PostModel>> getPostsForAdmin({
    required Department department,
    PostType? type,
  }) {
    try {
      Query query = _firestore
          .collection('posts')
          .where('department', isEqualTo: department.name)
          .orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to get posts for admin: $e');
    }
  }

  // Get posts created by a specific user (for CR)
  Stream<List<PostModel>> getPostsByCreator({
    required String creatorId,
    PostType? type,
  }) {
    try {
      Query query = _firestore
          .collection('posts')
          .where('createdBy', isEqualTo: creatorId)
          .orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to get posts by creator: $e');
    }
  }

  // Get a single post by ID
  Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return null;
      
      return PostModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get post: $e');
    }
  }

  // Search posts by title or content
  Stream<List<PostModel>> searchPosts({
    required Department department,
    required String searchQuery,
    int? year,
    PostType? type,
  }) {
    try {
      Query query = _firestore
          .collection('posts')
          .where('department', isEqualTo: department.name)
          .orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((post) {
              // Filter by year
              final yearMatch = post.year == "all" || (year != null && post.year == year.toString());
              
              // Filter by search query
              final searchMatch = post.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                                  post.content.toLowerCase().contains(searchQuery.toLowerCase());
              
              return yearMatch && searchMatch;
            })
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to search posts: $e');
    }
  }

  // Get recent posts (last 7 days)
  Stream<List<PostModel>> getRecentPosts({
    required Department department,
    int? year,
    PostType? type,
  }) {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      Query query = _firestore
          .collection('posts')
          .where('department', isEqualTo: department.name)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((post) => post.year == "all" || (year != null && post.year == year.toString()))
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to get recent posts: $e');
    }
  }

  // Get post statistics for admin dashboard
  Future<Map<String, int>> getPostStatistics(Department department) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('department', isEqualTo: department.name)
          .get();

      int totalPosts = snapshot.docs.length;
      int notices = 0;
      int schedules = 0;
      int thisWeek = 0;

      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      for (var doc in snapshot.docs) {
        final post = PostModel.fromMap(doc.data());
        
        if (post.type == PostType.notice) notices++;
        if (post.type == PostType.schedule) schedules++;
        if (post.createdAt.isAfter(weekAgo)) thisWeek++;
      }

      return {
        'total': totalPosts,
        'notices': notices,
        'schedules': schedules,
        'thisWeek': thisWeek,
      };
    } catch (e) {
      throw Exception('Failed to get post statistics: $e');
    }
  }
}

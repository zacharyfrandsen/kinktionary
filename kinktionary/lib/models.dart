class Term {
  final String id;
  final String name;
  final String category;
  final String short;
  final String? details;
  final List<String> related;
  final String? safetyNote;

  /// True for definitions that are still waiting for a human review.
  final bool draft;

  const Term({
    required this.id,
    required this.name,
    required this.category,
    required this.short,
    this.details,
    this.related = const [],
    this.safetyNote,
    this.draft = false,
  });

  factory Term.fromJson(Map<String, dynamic> j) => Term(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        short: j['short'] as String,
        details: j['details'] as String?,
        related: (j['related'] as List<dynamic>? ?? []).cast<String>(),
        safetyNote: j['safetyNote'] as String?,
        draft: (j['draft'] as bool?) ?? false,
      );
}

class LearningPath {
  final String id;
  final String title;
  final String blurb;
  final List<String> termIds;

  const LearningPath({
    required this.id,
    required this.title,
    required this.blurb,
    required this.termIds,
  });

  factory LearningPath.fromJson(Map<String, dynamic> j) => LearningPath(
        id: j['id'] as String,
        title: j['title'] as String,
        blurb: j['blurb'] as String,
        termIds: (j['termIds'] as List<dynamic>).cast<String>(),
      );
}

class ConsentTopic {
  final String title;
  final String body;

  const ConsentTopic({required this.title, required this.body});

  factory ConsentTopic.fromJson(Map<String, dynamic> j) =>
      ConsentTopic(title: j['title'] as String, body: j['body'] as String);
}

class UserProfile {
  final String displayName;
  final String handle;
  final String pronouns;
  final String bio;
  final String? photoUrl;

  const UserProfile({
    this.displayName = '',
    this.handle = '',
    this.pronouns = '',
    this.bio = '',
    this.photoUrl,
  });

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'handle': handle,
        'pronouns': pronouns,
        'bio': bio,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  factory UserProfile.fromMap(Map<String, dynamic> data) => UserProfile(
        displayName: data['displayName'] as String? ?? '',
        handle: data['handle'] as String? ?? '',
        pronouns: data['pronouns'] as String? ?? '',
        bio: data['bio'] as String? ?? '',
        photoUrl: data['photoUrl'] as String?,
      );
}

class CommunityReply {
  final String id;
  final String authorId;
  final String displayName;
  final String handle;
  final String text;
  final DateTime createdAt;

  const CommunityReply({
    this.id = '',
    required this.authorId,
    required this.displayName,
    required this.handle,
    required this.text,
    required this.createdAt,
  });

  CommunityReply copyWith({String? id}) => CommunityReply(
        id: id ?? this.id,
        authorId: authorId,
        displayName: displayName,
        handle: handle,
        text: text,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorId': authorId,
        'displayName': displayName,
        'handle': handle,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CommunityReply.fromMap(Map<String, dynamic> data) => CommunityReply(
        id: data['id'] as String? ?? '',
        authorId: data['authorId'] as String? ?? '',
        displayName: data['displayName'] as String? ?? 'Community member',
        handle: data['handle'] as String? ?? '',
        text: data['text'] as String? ?? '',
        createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class CommunityPost {
  final String id;
  final String ownerId;
  final String displayName;
  final String handle;
  final String text;
  final String topic;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;
  final List<CommunityReply> replies;

  const CommunityPost({
    required this.id,
    required this.ownerId,
    required this.displayName,
    required this.handle,
    required this.text,
    required this.topic,
    required this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.replies = const [],
  });

  CommunityPost copyWith({
    String? text,
    int? likeCount,
    bool? likedByMe,
    List<CommunityReply>? replies,
  }) =>
      CommunityPost(
        id: id,
        ownerId: ownerId,
        displayName: displayName,
        handle: handle,
        text: text ?? this.text,
        topic: topic,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        replies: replies ?? this.replies,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'displayName': displayName,
        'handle': handle,
        'text': text,
        'topic': topic,
        'createdAt': createdAt.toIso8601String(),
        'likeCount': likeCount,
        'likedByMe': likedByMe,
        'replies': replies.map((reply) => reply.toMap()).toList(),
      };

  factory CommunityPost.fromMap(Map<String, dynamic> data) => CommunityPost(
        id: data['id'] as String,
        ownerId: data['ownerId'] as String,
        displayName: data['displayName'] as String? ?? 'Community member',
        handle: data['handle'] as String? ?? '',
        text: data['text'] as String,
        topic: data['topic'] as String? ?? 'Experience',
        createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        likeCount: data['likeCount'] as int? ?? 0,
        likedByMe: data['likedByMe'] as bool? ?? false,
        replies: (data['replies'] as List<dynamic>? ?? const []).map((reply) {
          if (reply is String) {
            return CommunityReply(
              authorId: '',
              displayName: 'Community member',
              handle: '',
              text: reply,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            );
          }
          return CommunityReply.fromMap(
            Map<String, dynamic>.from(reply as Map),
          );
        }).toList(),
      );
}

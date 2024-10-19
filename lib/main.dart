import 'package:fcmyoutube/firebase_api.dart';
import 'package:fcmyoutube/notification_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart'; // تأكد من استيراد هذا الملف
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // استيراد الحزمة المناسبة
// import 'news_section.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initNotification();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7eSen TV',
      theme: ThemeData(
        primaryColor: Color(0xFF512da8),
        scaffoldBackgroundColor: Color(0xFF673ab7),
        cardColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF512da8),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF512da8),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: HomePage(),
      navigatorKey: navigatorKey,
      routes: {
        '/Notification_screen': (context) => const NotificationPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late Future<List> channelCategories;
  late Future<List> newsArticles;

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    channelCategories = fetchChannelCategories();
    newsArticles = fetchNews();
  }

  Future<void> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<List> fetchChannelCategories() async {
    try {
      final response = await http.get(Uri.parse(
          'https://st9.onrender.com/api/channel-categories?populate=channels'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Extract categories and include channels
        return List.from(data['data'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching channel categories: $e");
      return [];
    }
  }

  Future<List> fetchNews() async {
    try {
      final response = await http.get(Uri.parse('https://st9.onrender.com/api/news?populate=*'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List.from(data['data'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching news: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('7eSen TV'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ChannelsSection(channelCategories: channelCategories, openVideo: openVideo),
          NewsSection(newsArticles: newsArticles),
          // MatchesSection(matches: matches, openVideo: openVideo), // تم حذف هذه السطر
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.tv),
            label: 'القنوات',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.newspaper),
            label: 'الأخبار',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.futbol),
            label: 'المباريات',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  void openVideo(BuildContext context, String firstStreamLink, List<dynamic> streamLinks) {
    // Extract the stream names and their URLs
    List<Map<String, String>> streams = [];

    for (var streamLink in streamLinks) {
      var children = streamLink['children'];
      if (children != null && children.isNotEmpty) {
        var linkElement = children.firstWhere((child) => child['type'] == 'link', orElse: () => null);
        if (linkElement != null && linkElement['url'] != null && linkElement['children'] != null) {
          var streamName = linkElement['children'][0]['text'] ?? 'Unknown Stream';
          var streamUrl = linkElement['url'];
          streams.add({'name': streamName, 'url': streamUrl});
        }
      }
    }

    // Show a dialog to choose a stream
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('اختر جودة البث'),
          content: SingleChildScrollView(
            child: ListBody(
              children: streams.map((stream) {
                return ListTile(
                  title: Text(stream['name'] ?? 'Unknown Stream'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // Pass initialUrl and streamLinks to VideoPlayerScreen
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(
                        initialUrl: stream['url'] ?? '',
                        streamLinks: streams, // Pass the list of streams
                      ),
                    ));
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class ChannelsSection extends StatelessWidget {
  final Future<List> channelCategories;
  final Function openVideo;

  ChannelsSection({required this.channelCategories, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: channelCategories,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('خطأ في استرجاع القنوات'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لا توجد قنوات لعرضها'));
        } else {
          final categories = snapshot.data!;
          categories.sort((a, b) => a['id'].compareTo(b['id']));
          return ListView.separated(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return ChannelBox(category: categories[index], openVideo: openVideo);
            },
            separatorBuilder: (context, index) => SizedBox(height: 16),
          );
        }
      },
    );
  }
}

class ChannelBox extends StatelessWidget {
  final dynamic category;
  final Function openVideo;

  ChannelBox({required this.category, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Center(
          child: Text(
            category['name'] ?? 'Unknown Category', // Accessing name directly
            style: TextStyle(
              color: Color(0xFF673ab7),
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CategoryChannelsScreen(
                channels: category['channels'] ?? [], // Access channels directly
                openVideo: openVideo,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryChannelsScreen extends StatelessWidget {
  final List channels;
  final Function openVideo;

  CategoryChannelsScreen({required this.channels, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('القنوات'),
      ),
      body: ListView.separated(
        itemCount: channels.length,
        itemBuilder: (context, index) {
          return ChannelTile(channel: channels[index], openVideo: openVideo);
        },
        separatorBuilder: (context, index) => SizedBox(height: 16),
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  final dynamic channel;
  final Function openVideo;

  ChannelTile({required this.channel, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    // Print the channel data for debugging
    print("Channel Data: $channel"); // Debugging line

    // Ensure that channel and its attributes are not null
    if (channel == null || channel['name'] == null) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: ListTile(
          title: Center(
            child: Text(
              'Unknown Channel',
              style: TextStyle(
                color: Color(0xFF673ab7),
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    // Safely extract channel name
    String channelName = channel['name'] ?? 'Unknown Channel';

    // Extract StreamLink names safely
    List<dynamic> streamLinks = channel['StreamLink'] ?? [];
    List<String> streamNames = [];

    // Extract the names (like "stream1", "stream2") from the StreamLink
    for (var streamLink in streamLinks) {
      var children = streamLink['children'];
      if (children != null && children.isNotEmpty) {
        var linkText = children.firstWhere((child) => child['type'] == 'link', orElse: () => null);
        if (linkText != null && linkText['children'] != null && linkText['children'].isNotEmpty) {
          streamNames.add(linkText['children'][0]['text'] ?? 'Unknown Stream');
        }
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Center(
          child: Text(
            channelName,
            style: TextStyle(
              color: Color(0xFF673ab7),
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        subtitle: Center(
          child: Column(
            children: streamNames.map((streamName) {
              return Text(
                streamName,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 18,
                ),
              );
            }).toList(),
          ),
        ),
        onTap: () {
          if (streamLinks.isNotEmpty) {
            String? firstStreamLink = streamLinks[0]['children']
                .firstWhere((child) => child['url'] != null)['url'];
            openVideo(context, firstStreamLink, streamLinks); // Pass streamLinks here
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يوجد رابط للبث المباشر')));
          }
        },
      ),
    );
  }
}


class MatchesSection extends StatelessWidget {
  final Future<List> matches;
  final Function openVideo;

  MatchesSection({required this.matches, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: matches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('خطأ في استرجاع المباريات'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لا توجد مباريات لعرضها'));
        } else {
          final matches = snapshot.data!;

          List liveMatches = [];
          List upcomingMatches = [];
          List finishedMatches = [];

          for (var match in matches) {
            // تحقق من أن match ليس null وأنه يحتوي على attributes
            if (match == null || match['attributes'] == null) continue;

            final matchDateTime =
            DateFormat('HH:mm').parse(match['attributes']['matchTime']);
            final now = DateTime.now();
            final matchDateTimeWithToday = DateTime(now.year, now.month,
                now.day, matchDateTime.hour, matchDateTime.minute);

            if (matchDateTimeWithToday.isBefore(now) &&
                now.isBefore(
                    matchDateTimeWithToday.add(Duration(minutes: 110)))) {
              liveMatches.add(match);
            } else if (matchDateTimeWithToday.isAfter(now)) {
              upcomingMatches.add(match);
            } else {
              finishedMatches.add(match);
            }
          }

          // ترتيب المباريات القادمة من الأقرب للأبعد
          upcomingMatches.sort((a, b) {
            final matchTimeA =
            DateFormat('HH:mm').parse(a['attributes']['matchTime']);
            final matchTimeB =
            DateFormat('HH:mm').parse(b['attributes']['matchTime']);
            return matchTimeA.compareTo(matchTimeB);
          });

          return ListView(
            children: [
              ...liveMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo))
                  .toList(),
              ...upcomingMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo))
                  .toList(),
              ...finishedMatches
                  .map((match) => MatchBox(match: match, openVideo: openVideo))
                  .toList(),
            ],
          );
        }
      },
    );
  }
}

class MatchBox extends StatelessWidget {
  final Match match;
  final Function openVideo;

  MatchBox({required this.match, required this.openVideo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${match.teamA} vs ${match.teamB}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Match Time: ${match.matchTime}',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(match.commentator, style: TextStyle(color: Colors.grey)),
                Text(match.channel, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
        onTap: () => openVideo(context, match.streamLink),
      ),
    );
  }
}

class Match {
  final String teamA;
  final String teamB;
  final String matchTime;
  final String commentator;
  final String channel;
  final String? streamLink;

  Match({
    required this.teamA,
    required this.teamB,
    required this.matchTime,
    required this.commentator,
    required this.channel,
    this.streamLink,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      teamA: json['attributes']['teamA'],
      teamB: json['attributes']['teamB'],
      matchTime: json['attributes']['matchTime'],
      commentator: json['attributes']['commentator'] ?? 'Unknown Commentator',
      channel: json['attributes']['channel'] ?? 'Unknown Channel',
      streamLink: json['attributes']['streamLink'],
    );
  }
}


class NewsSection extends StatelessWidget {
  final Future<List> newsArticles;

  NewsSection({required this.newsArticles});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: newsArticles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('خطأ في استرجاع الأخبار'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لا توجد أخبار لعرضها'));
        } else {
          final articles = snapshot.data!;
          return ListView.separated(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index]['attributes'];
              return NewsBox(article: article);
            },
            separatorBuilder: (context, index) => SizedBox(height: 8),
          );
        }
      },
    );
  }
}

class NewsBox extends StatelessWidget {
  final dynamic article;

  NewsBox({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (article['link'] != null && article['link'].isNotEmpty) {
          _launchURL(article['link']);
        }
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              article['image']['data']['attributes']['url'],
              width: double.infinity,
              height: 280,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article['title'] ?? 'Unknown Title',
                    style: TextStyle(
                      color: Color(0xFF673ab7),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    article['content'] ?? 'No content available',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article['date'] != null
                            ? DateFormat('yyyy-MM-dd')
                            .format(DateTime.parse(article['date']))
                            : 'No date available',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (article['link'] != null &&
                              article['link'].isNotEmpty) {
                            _launchURL(article['link']);
                          }
                        },
                        child: Text(
                          'المزيد',
                          style: TextStyle(
                            color: Color(0xFF673ab7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchURL(String url) async {
    try {
      await launch(url, forceSafariVC: false, forceWebView: false);
    } catch (e) {
      print('Could not launch $url: $e');
      // يمكنك هنا إضافة كود لفتح المتصفح بشكل يدوي إذا لزم الأمر
      // مثل استخدام launch('https://www.google.com') كبديل
    }
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String initialUrl; // The URL to play initially
  final List<dynamic> streamLinks; // List of streaming links

  VideoPlayerScreen({required this.initialUrl, required this.streamLinks});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  bool _isControlsVisible = true;
  bool _isFullScreen = false;

  List<double> aspectRatios = [16 / 9, 4 / 3, 18 / 9, 21 / 9]; // Available aspect ratios
  int currentAspectRatioIndex = 0; // To keep track of the current aspect ratio

  @override
  void initState() {
    super.initState();
    _initializePlayer(widget.initialUrl);
    // Hide the status bar and navigation bar when entering full-screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _initializePlayer(String url) {
    _videoPlayerController = VideoPlayerController.network(url)
      ..initialize().then((_) {
        setState(() {
          _videoPlayerController.play();
        });
      })
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    // Restore the system UI when exiting the video player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControlsVisibility() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
      } else {
        _videoPlayerController.play();
      }
    });
  }

  void _toggleAspectRatio() {
    setState(() {
      currentAspectRatioIndex = (currentAspectRatioIndex + 1) % aspectRatios.length;
    });
  }

  void _changeStream(String url) {
    _videoPlayerController.pause();
    _initializePlayer(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('مشغل الفيديو'),
        actions: widget.streamLinks.map<Widget>((link) {
          final name = link['children'].firstWhere((child) => child['url'] != null)['url'];
          return TextButton(
            onPressed: () => _changeStream(name), // Change stream on button press
            child: Text(name ?? 'رابط غير متاح', style: TextStyle(color: Colors.white)),
          );
        }).toList(),
      ),
      body: GestureDetector(
        onTap: _toggleControlsVisibility,
        child: Stack(
          children: [
            Center(
              child: _videoPlayerController.value.isInitialized
                  ? AspectRatio(
                aspectRatio: aspectRatios[currentAspectRatioIndex], // Use the changing aspect ratio
                child: VideoPlayer(_videoPlayerController),
              )
                  : Container(color: Colors.black),
            ),
            if (_isControlsVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          _videoPlayerController.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        icon: Icon(Icons.aspect_ratio, color: Colors.white),
                        onPressed: _toggleAspectRatio,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _isFullScreen
          ? FloatingActionButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Icon(Icons.arrow_back),
        backgroundColor: Colors.black,
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}















import 'package:flutter/material.dart';
import 'constants.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // الجزء العلوي: بوستر الفيلم الكبير (مثل صورة تيتانيك)
          SliverToBoxAdapter(
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage("رابط_البوستر"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TITANIC SINKS TONIGHT", 
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.play_arrow, color: Colors.black),
                            label: Text("تشغيل الآن", style: TextStyle(color: Colors.black)),
                            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFFD700)),
                          ),
                          SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.add, color: Colors.white),
                            label: Text("قائمتي", style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          // قسم تصنيفات الأفلام (مثل واجهة TOD)
          _buildSectionTitle("مسلسلات مصرية"),
          _buildMoviesList(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(title, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMoviesList() {
    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 10,
          itemBuilder: (context, index) => Container(
            width: 140,
            margin: EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[900],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network("رابط_بوستر_فيلم", fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

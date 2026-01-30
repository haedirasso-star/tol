import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart'; // ستحتاج لإضافة مكتبة shimmer في pubspec.yaml

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!, // لون القاعدة (أسود غامق)
      highlightColor: const Color(0xFFFFD700).withOpacity(0.2), // لمعان ذهبي خفيف
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: 9, // عرض 9 هياكل أثناء التحميل
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}

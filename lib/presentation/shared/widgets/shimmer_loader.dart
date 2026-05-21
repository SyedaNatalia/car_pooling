import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';

/// Generic shimmer placeholder box.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EAF0),
      highlightColor: const Color(0xFFF5F5FA),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton card that mimics a ride result card while data loads.
class RideCardSkeleton extends StatelessWidget {
  const RideCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EAF0),
      highlightColor: const Color(0xFFF5F5FA),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 13, width: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 6),
                      Container(height: 11, width: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                ),
                Container(width: 52, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(height: 12, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                const Spacer(),
                Container(height: 12, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(height: 12, width: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                const Spacer(),
                Container(height: 26, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen shimmer list for ride results.
class RideListSkeleton extends StatelessWidget {
  final int count;
  const RideListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const RideCardSkeleton(),
    );
  }
}

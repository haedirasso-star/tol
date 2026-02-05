import 'package:equatable/equatable.dart';
import '../../../domain/entities/content.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<Content> featuredContent;
  final List<Content> trendingContent;
  final List<Content> continueWatching;
  final List<Content> newReleases;
  final List<Content> recommended;
  final List<Content> movies;
  final List<Content> series;
  final List<Content> sportsContent;
  final List<Content> liveContent;

  const HomeLoaded({
    required this.featuredContent,
    required this.trendingContent,
    required this.continueWatching,
    required this.newReleases,
    required this.recommended,
    required this.movies,
    required this.series,
    required this.sportsContent,
    required this.liveContent,
  });

  @override
  List<Object?> get props => [
        featuredContent,
        trendingContent,
        continueWatching,
        newReleases,
        recommended,
        movies,
        series,
        sportsContent,
        liveContent,
      ];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}

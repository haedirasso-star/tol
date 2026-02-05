import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/get_trending_content.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetTrendingContent getTrendingContent;

  HomeBloc({required this.getTrendingContent}) : super(HomeInitial()) {
    on<LoadHomeContent>(_onLoadHomeContent);
  }

  Future<void> _onLoadHomeContent(
    LoadHomeContent event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    try {
      final result = await getTrendingContent();
      emit(HomeLoaded(
        featuredContent: result.featuredContent,
        trendingContent: result.trendingContent,
        continueWatching: result.continueWatching,
        newReleases: result.newReleases,
        recommended: result.recommended,
        movies: result.movies,
        series: result.series,
        sportsContent: result.sportsContent,
        liveContent: result.liveContent,
      ));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}

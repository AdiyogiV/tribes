/// Loading state for dashboard data
enum DashboardLoadState {
  initial,
  loading,
  loaded,
  error,
}

/// Consolidated loading state for all dashboard data sources
class DashboardLoadingState {
  final DashboardLoadState sky;
  final DashboardLoadState events;
  final DashboardLoadState muhurat;
  final int skyRetryCount;
  final String? errorMessage;

  const DashboardLoadingState({
    this.sky = DashboardLoadState.initial,
    this.events = DashboardLoadState.initial,
    this.muhurat = DashboardLoadState.initial,
    this.skyRetryCount = 0,
    this.errorMessage,
  });

  bool get isAnyLoading =>
      sky == DashboardLoadState.loading ||
      events == DashboardLoadState.loading ||
      muhurat == DashboardLoadState.loading;

  bool get isAllLoaded =>
      sky == DashboardLoadState.loaded &&
      events == DashboardLoadState.loaded &&
      muhurat == DashboardLoadState.loaded;

  bool get isSkyLoaded => sky == DashboardLoadState.loaded;
  bool get isSkyLoading => sky == DashboardLoadState.loading;
  bool get isEventsLoaded => events == DashboardLoadState.loaded;
  bool get isMuhuratLoading => muhurat == DashboardLoadState.loading;

  DashboardLoadingState copyWith({
    DashboardLoadState? sky,
    DashboardLoadState? events,
    DashboardLoadState? muhurat,
    int? skyRetryCount,
    String? errorMessage,
  }) {
    return DashboardLoadingState(
      sky: sky ?? this.sky,
      events: events ?? this.events,
      muhurat: muhurat ?? this.muhurat,
      skyRetryCount: skyRetryCount ?? this.skyRetryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

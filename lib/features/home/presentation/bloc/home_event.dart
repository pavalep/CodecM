import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHomeData extends HomeEvent {
  final bool refresh;
  const LoadHomeData({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

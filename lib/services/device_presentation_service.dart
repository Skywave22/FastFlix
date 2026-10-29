/// The active presentation, including the user's override, used by deep links
/// and navigation.
class DevicePresentationService {
  DevicePresentationService._();
  static final instance = DevicePresentationService._();

  bool isTelevision = false;
}

class FluxState {
  static final Map<Type, dynamic> _services = {};
  static final Map<String, Map<Type, dynamic>> _scopedServices = {};

  static T inject<T>(T service) {
    _services[T] = service;
    return service;
  }

  static T injectScoped<T>(T service, String scope) {
    _scopedServices.putIfAbsent(scope, () => {});
    _scopedServices[scope]![T] = service;
    return service;
  }

  static T find<T>() {
    if (!_services.containsKey(T)) {
      throw Exception("Service of type $T not found");
    }
    return _services[T] as T;
  }

  static T findScoped<T>(String scope) {
    if (!_scopedServices.containsKey(scope) || !_scopedServices[scope]!.containsKey(T)) {
      throw Exception("Service of type $T not found in scope $scope");
    }
    return _scopedServices[scope]![T] as T;
  }

  static void clearScope(String scope) {
    _scopedServices.remove(scope);
  }
}
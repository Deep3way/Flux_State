/// Dependency injection utilities for managing services in [FluxState].
class FluxState {
  static final Map<Type, dynamic> _services = {};
  static final Map<String, Map<Type, dynamic>> _scopedServices = {};

  /// Registers a global [service] of type [T].
  static T inject<T>(T service) {
    _services[T] = service;
    return service;
  }

  /// Registers a [service] of type [T] in a specific [scope].
  static T injectScoped<T>(T service, String scope) {
    _scopedServices.putIfAbsent(scope, () => {});
    _scopedServices[scope]![T] = service;
    return service;
  }

  /// Retrieves a global service of type [T]. Throws if not found.
  static T find<T>() {
    if (!_services.containsKey(T)) {
      throw Exception("Service of type $T not found");
    }
    return _services[T] as T;
  }

  /// Retrieves a service of type [T] from a [scope]. Throws if not found.
  static T findScoped<T>(String scope) {
    if (!_scopedServices.containsKey(scope) ||
        !_scopedServices[scope]!.containsKey(T)) {
      throw Exception("Service of type $T not found in scope $scope");
    }
    return _scopedServices[scope]![T] as T;
  }

  /// Clears all services in a specific [scope].
  static void clearScope(String scope) {
    _scopedServices.remove(scope);
  }
}

/* eslint-disable no-unused-vars, no-undef */
var _elliotdickison$elm_firebase$Native_Firebase = (function() {

  // TODO: Throw errors if window.firebase isn't found...
  var firebase = window.firebase
  var scheduler = _elm_lang$core$Native_Scheduler
  var Nothing = _elm_lang$core$Maybe$Nothing
  var Just = _elm_lang$core$Maybe$Just

  var getApp = (function() {
    var apps = {}
    return function(config) {
      if (!apps[config.name]) {
        apps[config.name] =
          firebase.initializeApp(mapConfig(config), config.name)
      }
      return apps[config.name]
    }
  }())

  function getDatabase(config) {
    return getApp(config).database()
  }

  function mapConfig(config) {
    return Object.assign({}, config, {
      databaseURL: config.databaseUrl, // Different naming conventions...
    })
  }

  function mapError(error) {
    switch (error.code) {
    case "PERMISSION_DENIED":
      return { ctor: "PermissionDenied" }
    default:
      return { ctor: "OtherError", _0: error.code }
    }
  }

  function mapEvent(event) {
    switch(event.ctor) {
    case "Change":
      return "value"
    case "ChildAdd":
      return "child_added"
    case "ChildChange":
      return "child_changed"
    case "ChildRemove":
      return "child_removed"
    case "ChildMove":
      return "child_moved"
    }
  }

  function set(config, path, data) {
    return scheduler.nativeBinding(function(callback) {
      try {
        getDatabase(config).ref(path).set(data)
          .then(function() {
            callback(scheduler.succeed())
          })
          .catch(function(error) {
            callback(scheduler.fail(mapError(error)))
          })
      } catch (error) {
        callback(scheduler.fail(mapError(error)))
      }
    })
  }

  function get(config, path) {
    return scheduler.nativeBinding(function(callback) {
      try {
        getDatabase(config).ref(path).once("value")
          .then(function(snapshot) {
            callback(scheduler.succeed(snapshot.val()))
          })
          .catch(function(error) {
            callback(scheduler.fail(mapError(error)))
          })
      } catch (error) {
        callback(scheduler.fail(mapError(error)))
      }
    })
  }


  function listen(config, path, event, handler) {
    return scheduler.nativeBinding(function(callback) {
      var ref = getDatabase(config).ref(path)
      var mappedEvent = mapEvent(event)
      ref.on(mappedEvent, function(snapshot, prevKey) {
        var maybePrevKey = prevKey ? Just(prevKey) : Nothing
        scheduler.rawSpawn(A2(handler, snapshot.val(), maybePrevKey))
      })
      callback(scheduler.succeed())
    })
  }

  function stop(config, path, event) {
    return scheduler.nativeBinding(function(callback) {
      var mappedEvent = mapEvent(event)
      getDatabase(config).ref(path).off(mappedEvent)
      callback(schedule.succeed())
    })
  }

  return {
    set: F3(set),
    get: F2(get),
    listen: F4(listen),
    stop: F3(stop),
  }
}())
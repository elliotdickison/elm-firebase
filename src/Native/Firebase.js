/* eslint-disable no-unused-vars, no-undef */
const _elliotdickison$elm_firebase$Native_Firebase = (function() {

  // TODO: Throw errors if window.firebase isn't found...

  const scheduler = _elm_lang$core$Native_Scheduler
  const Nothing = _elm_lang$core$Maybe$Nothing
  const Just = _elm_lang$core$Maybe$Just

  const getApp = (function() {
    const apps = {}
    return config => {
      if (!apps[config.name]) {
        apps[config.name] = window.firebase.initializeApp(Object.assign({}, config, {
          databaseURL: config.databaseUrl, // Different naming conventions...
        }), config.name)
      }
      return apps[config.name]
    }
  }())

  const getDatabase = config =>
    getApp(config).database()

  const mapDatabaseError = error => {
    switch (error.code) {
    case "PERMISSION_DENIED":
      return { ctor: "PermissionDenied" }
    default:
      return { ctor: "OtherError", _0: error.code }
    }
  }

  const mapEvent = event => {
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

  const set = (config, path, data) =>
    scheduler.nativeBinding(callback => {
      try {
        getDatabase(config).ref(path).set(data)
          .then(() => callback(scheduler.succeed()))
          .catch(error => callback(scheduler.fail(mapDatabaseError(error))))
      } catch (error) {
        callback(scheduler.fail(mapDatabaseError(error)))
      }
    })

  const get = (config, path) =>
    scheduler.nativeBinding(callback => {
      try {
        getDatabase(config).ref(path).once("value")
          .then(snapshot => callback(scheduler.succeed(snapshot.val())))
          .catch(error => callback(scheduler.fail(mapDatabaseError(error))))
      } catch (error) {
        callback(scheduler.fail(mapDatabaseError(error)))
      }
    })

  const listen = (config, path, event, handler, cb) =>
    scheduler.nativeBinding(callback => {
      const callHandler = (snapshot, prevKey) => {
        const maybePrevKey = prevKey ? Just(prevKey) : Nothing
        scheduler.rawSpawn(A2(handler, snapshot.val(), maybePrevKey))
      }
      const ref = getDatabase(config).ref(path)
      const mappedEvent = mapEvent(event)
      ref.on(mappedEvent, callHandler)
      callback(scheduler.succeed(listener))
      return () => ref.off(mappedEvent, callHandler)
    })

  const stop = (config, path, event) =>
    scheduler.nativeBinding(callback => {
      const mappedEvent = mapEvent(event)
      getDatabase(config).ref(path).off(mappedEvent)
      callback(schedule.succeed())
    })

  return {
    set: F3(set),
    get: F2(get),
    listen: F4(listen),
    stop: F3(stop),
  }
}())
/* eslint-disable no-unused-vars, no-undef */
const _elliotdickison$elm_firebase$Native_Firebase = (function() {

  const scheduler = _elm_lang$core$Native_Scheduler
  const Nothing = _elm_lang$core$Maybe$Nothing
  const Just = _elm_lang$core$Maybe$Just

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

  const initialize = config =>
    scheduler.nativeBinding(callback => {
      const app = window.firebase.initializeApp(Object.assign({}, config, {
        databaseURL: config.databaseUrl, // Different naming conventions...
      }))
      callback(scheduler.succeed(app))
    })

  const set = (app, path, data) =>
    scheduler.nativeBinding(callback => {
      try {
        app.database().ref(path).set(data)
          .then(() => callback(scheduler.succeed()))
          .catch(error => callback(scheduler.fail(mapDatabaseError(error))))
      } catch (error) {
        callback(scheduler.fail(mapDatabaseError(error)))
      }
    })

  const get = (app, path) =>
    scheduler.nativeBinding(callback => {
      try {
        app.database().ref(path).once("value")
          .then(snapshot => callback(scheduler.succeed(snapshot.val())))
          .catch(error => callback(scheduler.fail(mapDatabaseError(error))))
      } catch (error) {
        callback(scheduler.fail(mapDatabaseError(error)))
      }
    })

  const listen = (app, path, event, handler, cb) =>
    scheduler.nativeBinding(callback => {
      const callHandler = (snapshot, prevKey) => {
        const maybePrevKey = prevKey ? Just(prevKey) : Nothing
        scheduler.rawSpawn(A2(handler, snapshot.val(), maybePrevKey))
      }
      const ref = app.database().ref(path)
      const mappedEvent = mapEvent(event)
      const stop = () => ref.off(mappedEvent, callHandler)
      const listener = { stop }
      ref.on(mappedEvent, callHandler)
      callback(scheduler.succeed(listener))
      return () => {
        if (listener && listener.stop) listener.stop()
      }
    })

  const stop = listener =>
    scheduler.nativeBinding(callback => {
      listener.stop()
      callback(schedule.succeed())
    })

  return {
    initialize,
    set: F3(set),
    get: F2(get),
    listen: F4(listen),
    stop,
  }
}())
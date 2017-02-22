/* eslint-disable no-unused-vars, no-undef */
const _elliotdickison$elm_firebase$Native_Firebase = (function() {

  const scheduler = _elm_lang$core$Native_Scheduler

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

  const on = (app, path, event) =>
    scheduler.nativeBinding(callback => {
      // TODO: Cancel callback + error handling
      app.database().ref(path).on(mapEvent(event), (snapshot, prevKey) => {
        callback(schedule.succeed({
          ctor: "_Tuple2",
          _0: snapshot.val(),
          _1: prevKey,
        }))
      })
    })

  return {
    initialize,
    set: F3(set),
    get: F2(get),
  }
}())
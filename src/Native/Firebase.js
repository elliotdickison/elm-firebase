/* eslint-disable no-unused-vars, no-undef */
const _elliotdickison$elm_firebase$Native_Firebase = (function() {

  const scheduler = _elm_lang$core$Native_Scheduler

  const mapDatabaseError = error => {
    switch (error.code) {
    case "PERMISSION_DENIED":
      return { ctor: "PermissionError" }
    default:
      return { ctor: "OtherError", _0: error.code }
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

  return {
    initialize,
    set: F3(set),
    get: F2(get),
  }
}())
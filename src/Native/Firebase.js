/* eslint-disable no-unused-vars, no-undef */
const _elliotdickison$elm_firebase$Native_Firebase = (function() {

  const initialize = config =>
    _elm_lang$core$Native_Scheduler.nativeBinding(callback => {
      const app = window.firebase.initializeApp(Object.assign({}, config, {
        databaseURL: config.databaseUrl, // Different naming conventions...
      }))
      callback(_elm_lang$core$Native_Scheduler.succeed(app))
    })

  const transformError = error => {
    switch (error.code) {
      case "PERMISSION_DENIED":
        return { ctor: "PermissionError" }
      default:
        return { ctor: "OtherError", _0: error.code }
    }
  }

  const set = (app, path, data) =>
    _elm_lang$core$Native_Scheduler.nativeBinding(callback => {
      try {
        app.database().ref(path).set(data)
          .then(() => callback(_elm_lang$core$Native_Scheduler.succeed()))
          .catch(error => callback(_elm_lang$core$Native_Scheduler.fail(transformError(error))))
      } catch (error) {
        callback(_elm_lang$core$Native_Scheduler.fail(transformError(error)))
      }
    })

  return {
    initialize,
    set: F3(set),
  }
}())
// eslint-disable-next-line no-unused-vars
var _elliotdickison$elm_firebase$Native_Firebase = (function() {

  /**
   * HELPERS
   */

  function shallowEq(a, b) {
    var keys = Object.keys(a)
    if (keys.length !== Object.keys(b).length) {
      return false
    } else {
      return keys.reduce(function(eq, key) {
        return a[key] === b[key] ? eq : false
      }, true)
    }
  }

  function mapConfigIn(config) {
    return Object.assign({}, config, {
      databaseURL: config.databaseUrl, // Different naming conventions...
    })
  }

  var getApp = (function() {
    var appList = []
    return function(config) {
      var newApp
      var existingApp = appList.filter(function(app) {
        return shallowEq(app.config, config)
      })[0]
      if (existingApp) {
        return existingApp.instance
      } else {
        newApp = firebase.initializeApp(mapConfigIn(config))
        appList.push({ config: config, instance: newApp })
        return newApp
      }
    }
  }())

  return {
    getApp: getApp,
  }
}())
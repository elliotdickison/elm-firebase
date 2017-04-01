/* eslint-disable no-unused-vars, no-undef */
var _elliotdickison$elm_firebase$Native_Firebase = (function() {

  /**
   * HELPERS
   */

  // TODO: Throw errors if window.firebase isn't found...
  // TODO: Remove try/catch blocks where not necessary...
  // TODO: Convert firebase permission warnings to errors

  var firebase = window.firebase

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

  function getRef(app, path, maybeQuery) {
    var refWithoutQuery = app.database().ref(path)
    return maybeQuery && maybeQuery.ctor === "Just"
      ? applyQueryToRef(refWithoutQuery, maybeQuery._0)
      : refWithoutQuery
  }

  function applyQueryToRef(ref, query) {
    var refWithOrder
    var refWithFilter
    switch (query.ctor) {
    case "OrderByKey": {
      refWithOrder = ref.orderByKey()
      refWithFilter = applyQueryFilterToRef(refWithOrder, query._0)
      return applyQueryLimitToRef(refWithFilter, query._1)
    }
    case "OrderByChild": {
      refWithOrder = ref.orderByChild(query._0)
      refWithFilter = applyQueryFilterToRef(refWithOrder, query._1)
      return applyQueryLimitToRef(refWithFilter, query._2)
    }
    case "OrderByValue": {
      refWithOrder = ref.orderByValue()
      refWithFilter = applyQueryFilterToRef(refWithOrder, query._0)
      return applyQueryLimitToRef(refWithFilter, query._1)
    }
    }
  }

  function applyQueryFilterToRef(ref, filter) {
    switch (filter.ctor) {
    case "NoFilter":
      return ref
    case "Matching":
      return ref.equalTo(filter._0)
    case "StartingAt":
      return ref.startAt(filter._0)
    case "EndingAt":
      return ref.endAt(filter._0)
    case "Between":
      return ref.startAt(filter._0).endAt(filter._1)
    }
  }

  function applyQueryLimitToRef(ref, limit) {
    switch (limit.ctor) {
    case "NoLimit":
      return ref
    case "First":
      return ref.limitToFirst(limit._0)
    case "Last":
      return ref.limitToLast(limit._0)
    }
  }

  function mapConfigIn(config) {
    return Object.assign({}, config, {
      databaseURL: config.databaseUrl, // Different naming conventions...
    })
  }

  function mapErrorOut(error) {
    switch (error.code) {
    case "PERMISSION_DENIED":
      return { ctor: "PermissionDenied" }
    case "UNEXPECTED_VALUE":
      return { ctor: "UnexpectedValue", _0: error.message }
    default:
      return { ctor: "OtherError", _0: error.code }
    }
  }

  function mapListOut(arr) {
    return arr
      .reverse()
      .reduce(function(list, item) {
        return { ctor: "::", _0: item, _1: list }
      }, { ctor: "[]" })
  }

  function mapEventIn(event) {
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

  /**
   * INIT
   */

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

  /**
   * WRITING DATA
   */

  function set(app, path, value) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
      var onComplete = function(error) {
        if (error) {
          callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
        } else {
          callback(_elm_lang$core$Native_Scheduler.succeed())
        }
      }
      try {
        getRef(app, path).set(value, onComplete)
      } catch (error) {
        callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  function push(app, path, maybeValue) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
      try {
        var value = maybeValue.ctor === "Just" ? maybeValue._0 : undefined
        var key = getRef(app, path).push(value)
        callback(_elm_lang$core$Native_Scheduler.succeed(key))
      } catch (error) {
        callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  function remove(app, path) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
      try {
        getRef(app, path).remove()
        callback(_elm_lang$core$Native_Scheduler.succeed())
      } catch (error) {
        callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  function map(app, path, func) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
      var transactionUpdate = function(value) {
        var nextValue = func(value === null ? _elm_lang$core$Maybe$Nothing : _elm_lang$core$Maybe$Just(value))
        if (nextValue.ctor === "Err") {
          throw { code: "UNEXPECTED_VALUE", message: nextValue._0 }
        } else if (nextValue.ctor === "Ok") {
          return nextValue._0.ctor === "Just"
            ? nextValue._0._0
            : null
        }
      }
      var onComplete = function(error, committed, snapshot) {
        if (error) {
          callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
        } else {
          callback(_elm_lang$core$Native_Scheduler.succeed(snapshot))
        }
      }
      try {
        getRef(app, path).transaction(transactionUpdate, onComplete)
      } catch (error) {
        callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  /**
   * READING DATA
   */

  function get(app, path, maybeQuery) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
      var successCallback = function(snapshot) {
        callback(_elm_lang$core$Native_Scheduler.succeed(snapshot))
      }
      var failureCallback = function(error) {
        callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
      }
      try {
        getRef(app, path, maybeQuery)
          .once("value", successCallback, failureCallback)
      } catch (error) {
        callback(_elm_lang$core$Native_Scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  /**
   * SUBSCRIBING TO DATA
   */

  function listen(app, path, maybeQuery, event, handler) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
      var mappedEvent = mapEventIn(event)
      getRef(app, path, maybeQuery).on(mappedEvent, function(snapshot, prevKey) {
        var maybePrevKey = prevKey === null ? _elm_lang$core$Maybe$Nothing : _elm_lang$core$Maybe$Just(prevKey)
        _elm_lang$core$Native_Scheduler.rawSpawn(A2(handler, snapshot, maybePrevKey))
      })
      callback(_elm_lang$core$Native_Scheduler.succeed())
    })
  }

  function stopListening(app, path, maybeQuery, event) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
      var mappedEvent = mapEventIn(event)
      getRef(app, path, maybeQuery).off(mappedEvent)
      callback(schedule.succeed())
    })
  }

  /**
   * SNAPSHOT
   */

  function snapshotToKey(snapshot) {
    return snapshot.key
  }

  function snapshotToValue(snapshot) {
    var value = snapshot.val()
    return value === null ? _elm_lang$core$Maybe$Nothing : _elm_lang$core$Maybe$Just(value)
  }

  function snapshotToList(snapshot) {
    var snapshotList = []
    snapshot.forEach(function(childSnapshot) {
      snapshotList.push(childSnapshot)
    })
    return mapListOut(snapshotList)
  }

  return {
    getApp: getApp,
    set: F3(set),
    push: F3(push),
    map: F3(map),
    remove: F2(remove),
    get: F3(get),
    listen: F5(listen),
    stopListening: F4(stopListening),
    snapshotToKey: snapshotToKey,
    snapshotToValue: snapshotToValue,
    snapshotToList: snapshotToList,
  }
}())
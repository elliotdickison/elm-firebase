/* eslint-disable no-unused-vars, no-undef */
var _elliotdickison$elm_firebase$Native_Firebase = (function() {

  /**
   * HELPERS
   */

  // TODO: Throw errors if window.firebase isn't found...
  // TODO: Remove try/catch blocks where not necessary...
  // TODO: Convert firebase permission warnings to errors

  var firebase = window.firebase
  var scheduler = _elm_lang$core$Native_Scheduler
  var Nothing = _elm_lang$core$Maybe$Nothing
  var Just = _elm_lang$core$Maybe$Just
  var Utils = _elm_lang$core$Native_Utils

  var getApp = (function() {
    var apps = {}
    return function(config) {
      if (!apps[config.name]) {
        apps[config.name] =
          firebase.initializeApp(mapConfigIn(config), config.name)
      }
      return apps[config.name]
    }
  }())

  function getDatabase(config) {
    return getApp(config).database()
  }

  function getRef(config, path, maybeQuery) {
    var refWithoutQuery = getDatabase(config).ref(path)
    return maybeQuery.ctor === "Just"
      ? applyQueryToRef(refWithoutQuery, maybeQuery._0)
      : refWithoutQuery
  }

  function applyQueryToRef(ref, query) {
    switch (query.ctor) {
    case "OrderByKey": {
      const refWithOrder = ref.orderByKey()
      const refWithFilter = applyQueryFilterToRef(refWithOrder, query._0)
      return applyQueryLimitToRef(refWithFilter, query._1)
    }
    case "OrderByChild": {
      const refWithOrder = ref.orderByChild(query._0)
      const refWithFilter = applyQueryFilterToRef(refWithOrder, query._1)
      return applyQueryLimitToRef(refWithFilter, query._2)
    }
    case "OrderByValue": {
      const refWithOrder = ref.orderByValue()
      const refWithFilter = applyQueryFilterToRef(refWithOrder, query._0)
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
   * WRITING DATA
   */

  function set(config, path, data) {
    return scheduler.nativeBinding(function(callback) {
      var onComplete = function(error) {
        if (error) {
          callback(scheduler.fail(mapErrorOut(error)))
        } else {
          callback(scheduler.succeed())
        }
      }
      try {
        getRef(config, path, Nothing).set(data, onComplete)
      } catch (error) {
        callback(scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  function map(config, path, func) {
    return scheduler.nativeBinding(function(callback) {
      var transactionUpdate = function(value) {
        var mappedValue = func(value === null ? Nothing : Just(value))
        return mappedValue.ctor === "Just"
          ? mappedValue._0
          : undefined
      }
      var onComplete = function(error, committed, snapshot) {
        if (error) {
          callback(scheduler.fail(mapErrorOut(error)))
        } else {
          callback(scheduler.succeed(snapshot))
        }
      }
      try {
        getRef(config, path, Nothing).transaction(transactionUpdate, onComplete)
      } catch (error) {
        callback(scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  /**
   * READING DATA
   */

  function get(config, path, maybeQuery) {
    return scheduler.nativeBinding(function(callback) {
      var successCallback = function(snapshot) {
        callback(scheduler.succeed(snapshot))
      }
      var failureCallback = function(error) {
        callback(scheduler.fail(mapErrorOut(error)))
      }
      try {
        getRef(config, path, maybeQuery)
          .once("value", successCallback, failureCallback)
      } catch (error) {
        callback(scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  /**
   * SUBSCRIBING TO DATA
   */

  function listen(config, path, maybeQuery, event, handler) {
    return scheduler.nativeBinding(function(callback) {
      var mappedEvent = mapEventIn(event)
      getRef(config, path, maybeQuery).on(mappedEvent, function(snapshot, prevKey) {
        var maybePrevKey = prevKey === null ? Nothing : Just(prevKey)
        scheduler.rawSpawn(A2(handler, snapshot, maybePrevKey))
      })
      callback(scheduler.succeed())
    })
  }

  function stopListening(config, path, event, maybeQuery) {
    return scheduler.nativeBinding(function(callback) {
      var mappedEvent = mapEventIn(event)
      getRef(config, path, maybeQuery).off(mappedEvent)
      callback(schedule.succeed())
    })
  }

  /**
   * PROCESSING SNAPSHOTS
   */

  function snapshotToKey(snapshot) {
    return snapshot.key
  }

  function snapshotToValue(snapshot) {
    var value = snapshot.val()
    return value === null ? Nothing : Just(value)
  }

  function snapshotToList(snapshot) {
    var snapshotList = []
    snapshot.forEach(function(childSnapshot) {
      snapshotList.push(childSnapshot)
    })
    return mapListOut(snapshotList)
  }

  return {
    set: F3(set),
    map: F3(map),
    get: F3(get),
    listen: F5(listen),
    stopListening: F4(stopListening),
    snapshotToKey: snapshotToKey,
    snapshotToValue: snapshotToValue,
    snapshotToList: snapshotToList,
  }
}())
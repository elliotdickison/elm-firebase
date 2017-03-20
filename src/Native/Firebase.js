/* eslint-disable no-unused-vars, no-undef */
var _elliotdickison$elm_firebase$Native_Firebase = (function() {

  // TODO: Throw errors if window.firebase isn't found...
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

  function getRefFromPath(config, path) {
    return getDatabase(config).ref(path)
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

  function set(config, path, data) {
    return scheduler.nativeBinding(function(callback) {
      try {
        getRefFromPath(config, path).set(data)
          .then(function() {
            callback(scheduler.succeed(data))
          })
          .catch(function(error) {
            callback(scheduler.fail(mapErrorOut(error)))
          })
      } catch (error) {
        callback(scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  function get(config, path) {
    return scheduler.nativeBinding(function(callback) {
      try {
        getRefFromPath(config, path).once("value")
          .then(function(snapshot) {
            callback(scheduler.succeed(snapshot.val()))
          })
          .catch(function(error) {
            callback(scheduler.fail(mapErrorOut(error)))
          })
      } catch (error) {
        callback(scheduler.fail(mapErrorOut(error)))
      }
    })
  }

  function getList(config, path, query) {
    return scheduler.nativeBinding(function(callback) {
      try {
        const ref = getRefFromPath(config, path)
        const refWithQuery = applyQueryToRef(ref, query)
        refWithQuery.once("value")
          .then(function(snapshot) {
            let items = []
            snapshot.forEach(function(itemSnapshot) {
              items.push(Utils.Tuple2(itemSnapshot.key, itemSnapshot.val()))
            })
            callback(scheduler.succeed(mapListOut(items)))
          })
          .catch(function(error) {
            callback(scheduler.fail(mapErrorOut(error)))
          })
      } catch (error) {
        callback(scheduler.fail(mapErrorOut(error)))
      }
    })
  }


  function listen(config, path, event, handler) {
    return scheduler.nativeBinding(function(callback) {
      var ref = getRefFromPath(config, path)
      var mappedEvent = mapEventIn(event)
      ref.on(mappedEvent, function(snapshot, prevKey) {
        var maybePrevKey = prevKey ? Just(prevKey) : Nothing
        scheduler.rawSpawn(A2(handler, snapshot.val(), maybePrevKey))
      })
      callback(scheduler.succeed())
    })
  }

  function stopListening(config, path, event) {
    return scheduler.nativeBinding(function(callback) {
      var mappedEvent = mapEventIn(event)
      getRefFromPath(config, path).off(mappedEvent)
      callback(schedule.succeed())
    })
  }

  return {
    set: F3(set),
    get: F2(get),
    getList: F3(getList),
    listen: F4(listen),
    stopListening: F3(stopListening),
  }
}())
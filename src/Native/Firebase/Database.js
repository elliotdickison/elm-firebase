// eslint-disable-next-line no-unused-vars
var _elliotdickison$elm_firebase$Native_Firebase_Database = (function() {

  /**
   * HELPERS
   */

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

  function mapEventIn(event) {
    switch(event.ctor) {
    case "ValueChanged":
      return "value"
    case "ChildAdded":
      return "child_added"
    case "ChildChanged":
      return "child_changed"
    case "ChildRemoved":
      return "child_removed"
    case "ChildMoved":
      return "child_moved"
    }
  }

  /**
   * WRITING
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

  function update(app, path, func) {
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
   * READING
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
   * SUBSCRIBING
   */

  function startListening(app, path, maybeQuery, event, handler) {
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
      callback(_elm_lang$core$Native_Scheduler.succeed())
    })
  }

  return {
    set: F3(set),
    push: F3(push),
    update: F3(update),
    remove: F2(remove),
    get: F3(get),
    startListening: F5(startListening),
    stopListening: F4(stopListening),
  }
}())
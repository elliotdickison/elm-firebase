// eslint-disable-next-line no-unused-vars
var _elliotdickison$elm_firebase$Native_Firebase_Database_Snapshot = (function() {

  function toKey(snapshot) {
    return snapshot.key
  }

  function toValue(snapshot) {
    var value = snapshot.val()
    return value === null
      ? _elm_lang$core$Maybe$Nothing
      : _elm_lang$core$Maybe$Just(value)
  }

  function toList(snapshot) {
    var snapshotList = []
    snapshot.forEach(function(childSnapshot) {
      snapshotList.push(childSnapshot)
    })
    return snapshotList
      .reverse()
      .reduce(function(list, item) {
        return { ctor: "::", _0: item, _1: list }
      }, { ctor: "[]" })
  }

  return {
    toKey: toKey,
    toValue: toValue,
    toList: toList,
  }
}())
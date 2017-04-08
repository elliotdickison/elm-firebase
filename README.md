* Disclaimer: This package contains a lot of native/kernel code. This makes it unsafe, opening up users to the very real possibility of runtime errors and difficult-to-debug situations. Given that, this package cannot be published to package.elm-lang.org (in its current form, anyway). Still, it's something that I wanted personally and it has been fun to work on. I hope that others find it useful in some capacity. *

# Firebase for Elm

Easy access to the Firebase platform from your Elm app.

```elm

import Firebase
import Firebase.Database as Database exposing ( Order(..), Filter(..), Limit(..) )
import Json.Encode as Encode

-- SETUP AN APP

firebase : Firebase.App
firebase =
    Firebase.getApp
        { apiKey = ""
        , authDomain = ""
        , databaseUrl = ""
        , storageBucket = ""
        , messagingSenderId = ""
        }

-- FETCH DATA

type Msg
  = UsersLoaded (Result Firebase.Error (List User))

type alias User = { ... }

decodeUser : String -> Encode.Value -> User
decodeUser key data =
  ...

fetchUsersOnce : Cmd Msg
fetchUsersOnce =
  Database.getList "users" (OrderByKey NoFilter NoLimit) decodeUser
    |> Database.attempt firebase UsersLoaded

subscribeToUsers : Sub Msg
subscribeToUsers =
  Database.listChanges "users" (OrderByKey NoFilter NoLimit) decodeUser
    |> Database.subscribe firebase UsersLoaded

```

## Why?

The goal of this package is to offer a simple, usable Elm API to Firebase. The goal of this package is *not* to mirror the Firebase API in Elm, or to include Elm bindings for every Firebase feature (there are [other](https://github.com/pairshaped/elm-firebase) [projects](https://github.com/ThomasWeiser/elmfire) for that). This package adds, changes, or omits features when it better serves the stated goals of simplicity and usability. For details on specific differences between this API and the original Firebase API, see the "Notable differences" section at the bottom of this README.

## Installation

I have not yet been able to find a good way to bundle the Firebase JavaScript client with this package. The main issue is that the client breaks when run in "strict mode", but all Elm output is included in an IIFE that invokes "strict mode". Because of this the Firebase client must be included separately (e.g. via a script tag on the host page).

...more here...

## Examples

Examples exist in the `examples` folder. In the future they should be linked to from here (along with live demos).

## Notable differences

This API diverges from the original Firebase API in some areas:

- The elm-firebase API does not surface Firebase's `Reference` or `Snapshot` objects. Instead, data paths are specified using plain strings and data is returned as `Json.Encode.Value` structures that are decoded into whatever shape is needed by the user. This simplifies the database API a good deal while only sacrificing a few convenience functions such as `Reference.parent` or `Snapshot.key`.
- elm-firebase offers separate database APIs for querying non-list data and data that is structured as a list. This reduces ambiguity that exists in the original Firebase API due to:
  - the fact that query parameters can be applied to any query (despite only being useful for list data)
  - the implicit dependencies between query parameters (e.g. a filter parameter is only effective after applying a sort)
  - the implicit dependency between the sort parameter and the function used to access the data (`Snapshot.val` is not sorted, `Snapshot.forEach` is)
  - the heuristics Firebase uses to determine whether `Snapshot.val` should return an array or an object
- Database "priorities" are omitted from elm-firebase. This feature exists in Firebase primarily for backwards compatibility, and can be replaced with the `OrderByChild` list query functionality.
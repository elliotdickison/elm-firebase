# Firebase for Elm

Easily access the Firebase platform from your Elm app

```elm

import Firebase
import Firebase.Database as Database exposing ( Order(..), Filter(..), Limit(..) )

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

-- SUBSCRIBE TO DATA

type Msg
  = UsersLoaded (Result Firebase.Error (List User))

users : Sub Msg
users =
  Database.listChanges "users" (OrderByValue NoFilter NoLimit) decodeUser firebase UsersLoaded

```

## Disclaimer

This is an experimental package that I've been building for fun/personal use. This will not be published to package.elm-lang.org (in its current form, anyway) for several reasons:

  - I have not yet been able to find a good way to bundle the Firebase JavaScript client with this package. The main issue is that the client breaks when run in "strict mode", but all Elm output is included in an IIFE that invokes "strict mode". Because of this the Firebase client must be included separately (e.g. via a script tag on the host page). It wouldn't make sense to publish this package while that implicit dependency exists.
  - This package uses the forbidden Effect Manager API for subscriptions.
  - This package contains a lot of native/kernel code, meaning that it is *much* more likely to have bugs than a pure Elm package. Because of this it would require explicit approval to be published, which I don't intend to pursue for the reasons stated above.

## Goals

The goal of this package is to offer a simple, usable Elm API for Firebase. The goal of this package is *not* to include Elm bindings for every feature of Firebase. When it serves the stated goals of simplicity and usability this package adds, changes, or omits features compared to Firebase's original API. A few examples of this:

  - The elm-firebase API does not surface Firebase's `Reference` or `Snapshot` database objects. Instead, data paths are specified using plain strings and data is returned as `Json.Encode.Value` structures that are decoded into whatever shape is needed by the user. This simplifies the database API a good deal while only sacrificing a few convenience functions such as `Reference.parent` or `Snapshot.key`.
  - elm-firebase offers a separate database API for querying data structured as a list. This reduces ambiguity in the original Firebase API around lists such as:
    - the fact that query parameters are only useful for lists but can be applied to any query
    - the implicit dependencies between query parameters (e.g. a filter parameter is only effective after applying a sort)
    - the implicit dependency between the sort parameter and the function used to access the data (`Snapshot.val` is not sorted, `Snapshot.forEach` is)
    - the heuristics Firebase uses to determine whether `Snapshot.val` should return an array or an object
  - Database "priorities" are omitted from elm-firebase. This feature exists in Firebase primarily for backwards compatibility, and can be replaced with the `OrderByChild` list query functionality.

## Examples

Examples will exist in the `examples` folder, and will be linked to from here (along with live demos).
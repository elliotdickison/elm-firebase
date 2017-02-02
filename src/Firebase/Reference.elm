module Firebase.Reference exposing (Reference, fromString, parent, child, root)


type Reference
    = Reference
    | StringReference String
    | ParentReference Reference
    | ChildReference Reference String
    | RootReference Reference


fromString : String -> Reference
fromString =
    StringReference


parent : Reference -> Reference
parent =
    ParentReference


child : Reference -> String -> Reference
child =
    ChildReference


root : Reference -> Reference
root =
    RootReference

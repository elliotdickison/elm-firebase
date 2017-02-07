require("index.html")
const firebase = require("firebase")

const Elm = require("src/Main.elm")

const root = document.getElementById("root")

Elm.Main.embed(root)

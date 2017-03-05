require("index.html")

// Set on the window so it's accessible to Elm firebase...
window.firebase = require("firebase")

const Elm = require("src/Main.elm")

const root = document.getElementById("root")

Elm.Main.embed(root)

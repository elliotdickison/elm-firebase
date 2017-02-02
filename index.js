require("index.html")
const firebase = require("firebase")

firebase.initializeApp({
  apiKey: "AIzaSyC6D2bQwHU61AaGabDTVQ531kyoiZ-aKZo",
  authDomain: "elm-firebase.firebaseapp.com",
  databaseURL: "https://elm-firebase.firebaseio.com",
  storageBucket: "elm-firebase.appspot.com",
  messagingSenderId: "488262915403",
})

const Elm = require("src/Main.elm")

const root = document.getElementById("root")

Elm.Main.embed(root)

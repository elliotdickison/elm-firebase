const path = require("path");
const DashboardPlugin = require("webpack-dashboard/plugin");
const production = process.env.NODE_ENV === "production"

const plugins = production
  ? []
  : [ new DashboardPlugin() ]

module.exports = {
  entry: {
    app: [
      "./index.js"
    ],
  },
  output: {
    path: path.resolve(__dirname + "/dist"),
    filename: "[name].js",
  },
  plugins,
  module: {
    loaders: [
      {
        test: /\.html$/,
        exclude: /node_modules/,
        loader: "file-loader?name=[name].[ext]",
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: production
          ? "elm-webpack-loader"
          : "elm-hot-loader!elm-webpack-loader",
      },
    ],
    noParse: /\.elm$/,
  },
  resolve: {
    modulesDirectories: [
      "node_modules",
      ".",
    ],
  },
  devServer: {
    historyApiFallback: true,
    port: 3000,
  },
}

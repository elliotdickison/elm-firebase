module.exports = {
    "env": {
        "browser": true,
        "es6": true,
    },
    "extends": "eslint:recommended",
    "rules": {
        "indent": [
            "error",
            2,
        ],
        "linebreak-style": [
            "error",
            "unix",
        ],
        "quotes": [
            "error",
            "double",
        ],
        "semi": [
            "error",
            "never",
        ],
    },
    "globals": {
        "firebase": false,
        "_elm_lang$core$Native_Scheduler": false,
        "_elm_lang$core$Maybe$Nothing": false,
        "_elm_lang$core$Maybe$Just": false,
        "A2": false,
        "F2": false,
        "F3": false,
        "F4": false,
        "F5": false,
    },
}
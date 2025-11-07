// .eslintrc.cjs  (o .eslintrc.js si así lo usas)
module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],

    // ⬇️ override al de Google (80) — cámbialo a 120 si quieres
    "max-len": ["error", {
      "code": 100,
      "tabWidth": 2,
      "ignoreStrings": true,
      "ignoreTemplateLiterals": true,
      "ignoreComments": true,
      "ignoreUrls": true,
    }],
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};

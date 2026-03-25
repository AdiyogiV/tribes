module.exports = {
    env: {
        browser: true,
        es6: true,
        node: true,
    },
    parserOptions: {
        ecmaVersion: 2022,
        sourceType: "module",
    },
    extends: [
        "eslint:recommended",
        "google",
    ],
    rules: {
        "no-restricted-globals": ["error", "name", "length"],
        "prefer-arrow-callback": "error",
        quotes: ["error", "double", { allowTemplateLiterals: true }],
        "max-len": ["warn", { code: 140 }],
        "new-cap": ["error", { capIsNewExceptions: ["functions"] }],
        "require-jsdoc": "off",
        "valid-jsdoc": "off",
        "object-curly-spacing": ["error", "always"],
        indent: ["warn", 4],
        "no-case-declarations": "off",
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



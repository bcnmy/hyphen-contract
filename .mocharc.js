module.exports = {
  'allow-uncaught': true,
  diff: true,
  extension: ['ts', 'js'],
  recursive: true,
  reporter: 'spec',
  require: ['ts-node/register', 'hardhat/register'], // ['ts-node/register/transpile-only'], (for yarn link <plugin>)
  slow: 300,
  spec: ['test/**/*.test.ts', 'test/**/*.test.js','test/**/*.tests.ts'],
  timeout: 0,
  ui: 'bdd',
  watch: false,
  'watch-files': ['src/**/*.sol', 'test/**/*.ts', 'test/**/*.js'],
};

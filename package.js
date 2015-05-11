// Meteor package definition.
Package.describe({
  name: 'urbanetic:bismuth-utility',
  version: '0.1.0',
  summary: 'A set of utility modules used in Bismuth apps.',
  git: 'https://github.com/urbanetic/bismuth-reports.git'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@0.9.0');
  api.use([
    'coffeescript',
    'jquery',
    'less',
    'templating',
    'underscore',
    'aramk:q@1.0.1_1',
    'aramk:utility@0.8.6'
    ],'client');
  // TODO(aramk) Perhaps expose the charts through the Vega object only to avoid cluttering the
  // namespace.
  api.export([
    'Csv'
  ], 'client');
  api.addFiles([
    'src/Csv.coffee'
  ], 'client');
});

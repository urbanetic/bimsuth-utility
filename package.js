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
    'underscore',
    'aramk:q@1.0.1_1',
    'aramk:utility@0.8.6'
  ], ['client', 'server']);
  api.use([
    'jquery',
    'less',
    'templating'
  ], 'client');
  // TODO(aramk) Perhaps expose the charts through the Vega object only to avoid cluttering the
  // namespace.
  api.export([
    'Csv'
  ], 'client');
  api.export([
    'FileLogger'
  ], 'server');
  api.export([
    'TaskRunner'
  ], ['client', 'server']);
  api.addFiles([
    'src/Csv.coffee'
  ], 'client');
  api.addFiles([
    'src/FileLogger.coffee'
  ], 'server');
  api.addFiles([
    'src/TaskRunner.coffee'
  ], ['client', 'server']);
});

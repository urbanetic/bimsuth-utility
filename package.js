// Meteor package definition.
Package.describe({
  name: 'urbanetic:bismuth-utility',
  version: '2.0.0',
  summary: 'A set of utilities for working with GIS apps.',
  git: 'https://github.com/urbanetic/bismuth-reports.git'
});

Npm.depends({
  'request': '2.37.0',
  'concat-stream': '1.4.7',
  'node-geocoder': '3.22.0'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@1.6.1');
  api.use([
    'coffeescript@2.2.1_1',
    'underscore',
    'aramk:q@1.0.1_1',
    'aramk:requirejs@2.1.15_1',
    'reactive-var@1.0.5',
    'urbanetic:accounts-ui@1.0.0_1',
    'urbanetic:bismuth-schema-utility@1.0.0',
    'urbanetic:utility@2.0.0'
  ], ['client', 'server']);
  // TODO(aramk) Weak dependency on aramk:file-upload@1.0.0, but causes cyclic dependencies.
  api.use([
    'urbanetic:bismuth-schema@1.0.0',
    'urbanetic:atlas-util@1.0.0',
    'peerlibrary:aws-sdk@2.1.47_1'
  ], ['client', 'server'], {weak: true});
  api.use([
    'jquery',
    'less',
    'templating@1.3.2'
  ], 'client');
  // TODO(aramk) Perhaps expose the charts through the Vega object only to avoid cluttering the
  // namespace.
  api.export([
    'Csv'
  ], 'client');
  api.export([
    'Request',
    'S3Utils',
    'Geocoder',
  ], 'server');
  api.export([
    'CounterLog',
    'DocMap',
    'ItemBuffer',
    'TaskRunner',
  ], ['client', 'server']);
  api.addFiles([
    'src/Csv.coffee'
  ], 'client');
  api.addFiles([
    'src/AccountsUtil.coffee',
    'src/CounterLog.coffee',
    'src/DocMap.coffee',
    'src/ItemBuffer.coffee',
    'src/TaskRunner.coffee',
  ], ['client', 'server']);
  api.addFiles([
    'src/Request.coffee',
    'src/S3Utils.coffee',
    'src/Geocoder.coffee'
  ], 'server');
});

// Meteor package definition.
Package.describe({
  name: 'urbanetic:bismuth-utility',
  version: '0.2.1',
  summary: 'A set of utilities for working with GIS apps.',
  git: 'https://github.com/urbanetic/bismuth-reports.git'
});

Npm.depends({
  'request': '2.37.0',
  'concat-stream': '1.4.7'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@1.2.0.1');
  api.use([
    'coffeescript',
    'underscore',
    'aramk:q@1.0.1_1',
    'aramk:requirejs@2.1.15_1',
    'aramk:utility@0.10.0',
    'reactive-var@1.0.5',
    'urbanetic:accounts-ui@0.2.2',
    'urbanetic:bismuth-schema-utility@0.2.0'
  ], ['client', 'server']);
  // TODO(aramk) Weak dependency on aramk:file-upload@0.4.0, but causes cyclic dependencies.
  api.use([
    'urbanetic:bismuth-schema@0.1.0',
    'urbanetic:atlas-util@0.3.0',
    'peerlibrary:aws-sdk@2.1.47_1'
  ], ['client', 'server'], {weak: true});
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
    'Request',
    'S3Utils'
  ], 'server');
  api.export([
    'CounterLog',
    'EntityImporter',
    'EntityUtils',
    'ItemBuffer',
    'TaskRunner',
    'ProjectUtils'
  ], ['client', 'server']);
  api.addFiles([
    'src/Csv.coffee'
  ], 'client');
  api.addFiles([
    'src/Request.coffee',
    'src/S3Utils.coffee'
  ], 'server');
  api.addFiles([
    'src/AccountsUtil.coffee',
    'src/CounterLog.coffee',
    'src/EntityImporter.coffee',
    'src/EntityUtils.coffee',
    'src/ItemBuffer.coffee',
    'src/TaskRunner.coffee',
    'src/ProjectUtils.coffee'
  ], ['client', 'server']);
});

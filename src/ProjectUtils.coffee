# Constructs a map of collection name to collection.

reNumberAfterName = /(\d+)(\s*)$/
incrementName = (name) ->
  if reNumberAfterName.test(name)
    name.replace reNumberAfterName, (match, m1, m2) -> (parseInt(m1) + 1) + m2
  else
    name + ' 2'

ProjectUtils =

  # @param {String} id - The ID of the project to serialize.
  # @returns {Object} JSON serialization of the given project and its models. IDs are unaltered.
  toJson: (id) ->
    project = Projects.findOne(id)
    unless project
      throw new Error('Project with ID ' + id + ' not found')
    result = {}
    result[Collections.getName(Projects)] = [project]
    collections = _.without(CollectionUtils.getAll(), Projects)
    _.each Collections.getMap(collections), (collection, name) ->
      result[name] = collection.findByProject(id).fetch()
    result

  # Constructs new models from the given JSON serialization. IDs are used to retain references
  # between the new models and new IDs are generated to replace those in the given JSON.
  # @param {Object} json - The serialized JSON. This object may be modified by this method - pass a
  #     clone if this is undesirable.
  # @param {Object} args
  # TODO(aramk) Add support for this or remove the option.
  # @param {Boolean} args.update - If true, no new models will be constructed. Instead, any existing
  #     models matching with matching IDs will be updated with the values in the given JSON.
  # @returns {Object.<String, Object>} A map of collection names to maps of old IDs to new IDs for
  #     the models in that collection.
  fromJson: (json, args) ->
    # Construct all models as new documents in the first pass, mapping old ID references to new IDs.
    # In the second pass, change all IDs to the new ones to maintain references in the new models.

    df = Q.defer()
    # A map of collection names to maps of model IDs from the input to the new IDs constructed.
    idMaps = {}

    createDfs = []
    collectionMap = Collections.getMap(CollectionUtils.getAll())
    _.each collectionMap, (collection, name) ->
      idMap = idMaps[name] = {}
      _.each json[name], (model) ->
        createDf = Q.defer()
        createDfs.push(createDf.promise)
        oldModelId = model._id
        delete model._id
        # TODO(aramk) Disabling validation is dangerous - only done here to avoid validation
        # errors which don't have messages at the moment. Improve collection2 to provide the
        # message returned from the validate method.
        collection.insert model, {validate: false}, (err, result) ->
          if err
            createDf.reject(err)
          else
            newModelId = result
            idMap[oldModelId] = newModelId
            createDf.resolve(newModelId)
    refDfs = []
    Q.all(createDfs).then(Meteor.bindEnvironment(
      ->
        _.each idMaps, (idMap, name) ->
          collection = collectionMap[name]
          _.each idMap, (newId, oldId) ->
            newModel = collection.findOne(newId)
            modifier = SchemaUtils.getRefModifier(newModel, collection, idMaps)
            if Object.keys(modifier.$set).length > 0
              refDf = Q.defer()
              refDfs.push(refDf.promise)
              collection.update newId, modifier, {validate: false}, (err, result) ->
                if err
                  refDf.reject(err)
                else
                  refDf.resolve(newId)
        Q.all(refDfs).then(
          -> df.resolve(idMaps)
          # TODO(aramk) Remove added models on failure.
          (err) -> df.reject(err)
        )
      )
      (err) -> df.reject(err)
    )
    df.promise

  # @params {String} name
  # @returns {String} The next available name base on the given name with an incremented numerical
  # suffix.
  getNextAvailableName: (name) ->
    newName = name
    while Projects.find({name: newName}).count() != 0
      newName = incrementName(newName)
    newName

  # @param {String} id - The ID of the project to duplicate.
  # @param {Object} [args]
  # @param {Function} [args.callback] - A callback which is passed the JSON documents from
  #     {@link #toJson()} and returns the JSON which is then passed into {@link #fromJson()}.
  # @returns {Object.<String, Object>} A map of collection names to maps of old IDs to new IDs for
  #     the models in that collection.
  duplicate: (id, args) ->
    json = @toJson(id)
    if args?.callback?
      json = args.callback(json) ? json
    @fromJson(json)

  downloadInBrowser: (id) ->
    Logger.info 'Exporting project', id
    json = @toJson(id)
    blob = Blobs.fromString(JSON.stringify(json), {type: 'application/json'})
    Blobs.downloadInBrowser(blob, 'project-' + id + '.json')

  zoomTo: ->
    projectId = Projects.getCurrentId()
    location = Projects.getLocationCoords(projectId)
    return unless location
    if location.latitude? and location.longitude?
      location.elevation ?= 5000
      Logger.debug 'Loading project location', location
      AtlasManager.zoomTo
        position: location
        # Aim the camera at the ground.
        orientation:
          rotation: 0
          tilt: -90
          bearing: 0
    else
      address = Projects.getLocationAddress(projectId)
      console.debug 'Loading project address', address
      AtlasManager.zoomTo {address: address}

  remove: (id) ->
    Meteor.call 'projects/remove', id, (err, result) ->
      Reports.removeLastOpened(id) unless err

  getDatedIdentifier: (id) ->
    id ?= Projects.getCurrentId()
    'project-' + id + '-' + Dates.toIdentifier()

  assertAuthorization: (projectId, userId) ->
    unless projectId?
      throw new Meteor.Error(500, 'No project specified when subscribing.')
    unless userId?
      throw new Meteor.Error(403, 'No user provided')
    unless AccountsUtil.isOwner(Projects.findOne(projectId), userId) || AccountsUtil.isAdmin(userId)
      throw new Meteor.Error(403, 'User ' + userId +
          ' not authorized to view collections of project ' + projectId)

  authorizePublish: (projectId, callback) ->
    # Ignore the request if no user ID exists.
    unless @userId then return []
    try
      ProjectUtils.assertAuthorization(projectId, @userId)
      if callback?
        return callback.call(@)
      else
        return true
    catch e
      Logger.error('Error in publications', e, e.stack)
      @error(e)
      return false unless callback?

Meteor.startup ->
  return unless Meteor.isServer

  ##################################################################################################
  # PROJECT DATE
  ##################################################################################################

  # Updating project or models in the project will update the modified date of a project.

  getCurrentDate = -> moment().toDate()
  updateProjectModifiedDate = _.throttle (projectId, userId) ->
    Projects.update projectId, $set: {dateModified: getCurrentDate(), userModified: userId}
  , 5000

  Projects.before.insert (userId, doc) ->
    unless doc.dateModified
      doc.dateModified = getCurrentDate()
      doc.userModified = userId

  Projects.before.update (userId, doc, fieldNames, modifier) ->
    modifier.$set ?= {}
    delete modifier.$unset?.dateModified
    modifier.$set.dateModified = getCurrentDate()
    modifier.$set.userModified = userId

  _.each _.without(CollectionUtils.getAll(), Projects), (collection) ->
    _.each ['insert', 'update'], (operation) ->
      collection.after[operation] (userId, doc) ->
        projectId = doc[SchemaUtils.projectIdProperty]
        return unless projectId
        updateProjectModifiedDate(projectId, userId)

  ##################################################################################################
  # DUPLICATE
  ##################################################################################################

  Meteor.methods
    'projects/duplicate': (id) ->
      userId = @userId
      ProjectUtils.assertAuthorization(id, userId)
      Promises.runSync -> ProjectUtils.duplicate(id).then Meteor.bindEnvironment (idMaps) ->
        newId = idMaps[Collections.getName(Projects)][id]
        Projects.update newId, $set: {dateModified: new Date, userModified: userId}

  ##################################################################################################
  # REMOVAL
  ##################################################################################################

  Projects.after.remove (userId, doc) ->
    Logger.info('Cleaning up after removing project', doc)
    id = doc._id
    selector = {projectId: id}
    _.each CollectionUtils.getAll(), (collection) ->
      count = collection.remove(selector)
      if count > 0
        console.log('Removed ' + count + ' ' + Collections.getName(collection))
    files = Files.find(selector).fetch()
    Logger.info('Removing files for project', doc, files)
    Files.remove(selector)

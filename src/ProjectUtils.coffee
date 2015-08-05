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
    Logger.info("Converting project #{id} to JSON...")
    project = Projects.findOne(id)
    unless project then throw new Error('Project with ID ' + id + ' not found')
    result = {}
    result[Collections.getName(Projects)] = [project]
    collections = _.without(CollectionUtils.getAll(), Projects)
    _.each Collections.getMap(collections), (collection, name) ->
      # TODO(aramk) This will ignore collectionType references which don't have "projectId" fields.
      result[name] = collection.findByProject?(id).fetch() ? []
    result

  # Constructs new models from the given JSON serialization. IDs are used to retain references
  # between the new models and new IDs are generated to replace those in the given JSON.
  # @param {Object} json - The serialized JSON. This object may be modified by this method - pass a
  #     clone if this is undesirable.
  # @param {Object} args
  # TODO(aramk) Add support for this or remove the option.
  # @param {Boolean} args.update - If true, no new models will be constructed. Instead, any existing
  #     models matching with matching IDs will be updated with the values in the given JSON.
  # @returns {Promise.<Object.<String, Object>>} A promise to return a map of collection names to
  #     maps of old IDs to new IDs for the models in that collection.
  fromJson: (json, args) ->
    Logger.info('Creating project from JSON...')

    # Construct all models as new documents in the first pass, mapping old ID references to new IDs.
    # In the second pass, change all IDs to the new ones to maintain references in the new models.

    df = Q.defer()
    # A map of collection names to maps of model IDs from the input to the new IDs constructed.
    idMaps = {}

    Logger.info('Inserting duplicate docs...')
    createDfs = []
    collectionMap = Collections.getMap(CollectionUtils.getAll())
    _.each collectionMap, (collection, name) ->
      idMap = idMaps[name] = {}
      _.each json[name], (model) ->
        oldModelId = model._id
        oldModel = collection.findOne(oldModelId)
        # Ignore documents in the JSON which don't have a projectId and exist in the collection,
        # indicating they should be shared between projects.
        projectId = model[SchemaUtils.projectIdProperty]
        return if collection != Projects && !projectId? && oldModel?
        createDf = Q.defer()
        createDfs.push(createDf.promise)
        delete model._id
        # TODO(aramk) Disabling validation is dangerous - only done here to avoid validation
        # errors which don't have messages at the moment. Improve collection2 to provide the
        # message returned from the validate method.
        collection.direct.insert model, (err, result) ->
          if err
            createDf.reject(err)
          else
            newModelId = result
            idMap[oldModelId] = newModelId
            createDf.resolve(newModelId)
      
    Logger.info('Resolving references...')
    refDfs = []
    allCreatePromise = Q.all(createDfs)
    allCreatePromise.fail(df.reject)
    allCreatePromise.then Meteor.bindEnvironment ->
      _.each idMaps, (idMap, name) ->
        collection = collectionMap[name]
        _.each idMap, (newId, oldId) ->
          newModel = collection.findOne(newId)
          modifier = SchemaUtils.getRefModifier(newModel, collection, idMaps)
          if Object.keys(modifier.$set).length > 0
            refDf = Q.defer()
            refDfs.push(refDf.promise)
            collection.direct.update newId, modifier, (err, result) ->
              if err
                refDf.reject(err)
              else
                refDf.resolve(newId)
      Q.all(refDfs).then(
        ->
          Logger.info('Project creation from JSON succeeded')
          df.resolve(idMaps)
        (err) ->
          # TODO(aramk) Remove added models on failure.
          Logger.error('Project creation from JSON failed', err)
          df.reject(err)
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
    Logger.info('Duplicating project', id, args)
    json = @toJson(id)
    if args?.callback?
      json = args.callback(json) ? json
    @fromJson(json).then (idMaps) ->
      console.log 'idMaps', JSON.stringify(idMaps)
      newProjectId = idMaps[Collections.getName(Projects)]?[id]
      Logger.info('Duplicated project', id, 'to new project', newProjectId)
      return idMaps

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
      location.elevation ?= 3000
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
    if Projects.isEnabled?(projectId) == false
      throw new Meteor.Error(403, 'Project is disabled')
    unless (AccountsUtil.isOwner(Projects.findOne(projectId), userId) ||
        AccountsUtil.isAdmin(userId) ||
        Projects.isPublic?(projectId))
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

  # Returns a boolean which is true when the given project is a public, the given user is not
  # the owner of this project, and is not an admin.
  #  * userId - A string of the user ID. If not provided, the current user ID is used (if any).
  #  * projectId - A string of the project ID. If unprovided, the current project ID is used
  #                (if any).
  isVisitingUser: (userId, projectId) ->
    userId ?= Meteor.userId()
    projectId ?= Projects.getCurrentId()
    project = Projects.findOne(_id: projectId)
    Projects.isPublic(projectId) && !AccountsUtil.isOwnerOrAdmin(project, userId)

  isOwnerOrAdmin: (projectId, userId) ->
    projectId ?= Projects.getCurrentId()
    project = Projects.findOne(_id: projectId)
    userId ?= Meteor.userId()
    AccountsUtil.isOwnerOrAdmin(project, userId)

Meteor.startup ->
  return unless Meteor.isServer

  ##################################################################################################
  # PROJECT DATE
  ##################################################################################################

  # Updating project or models in the project will update the modified date of a project.

  getCurrentDate = -> moment().toDate()
  updateProjectModifiedDate = _.throttle Meteor.bindEnvironment (projectId, userId) ->
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
        Logger.info('Removed ' + count + ' ' + Collections.getName(collection))
    files = Files.find(selector).fetch()
    Logger.info('Removing files for project', doc, files)
    Files.remove(selector)

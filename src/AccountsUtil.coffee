_.extend AccountsUtil,

  allowOwnerOfProject: (userId, doc) ->
    projectId = doc[SchemaUtils.projectIdProperty]
    # Allow if no project field exists.
    return true unless projectId?
    project = Projects.findOne(projectId)
    # Deny if given project doesn't exist.
    return unless project
    AccountsUtil.isOwnerOrAdmin(project, userId)
  
  setUpProjectAllow: (collection) ->
    allowOwnerOfProject = @allowOwnerOfProject.bind(@)
    collection.allow
      insert: (userId, doc) -> userId?
      update: allowOwnerOfProject
      remove: allowOwnerOfProject

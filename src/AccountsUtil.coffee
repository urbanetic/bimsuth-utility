_.extend AccountsUtil,

  allowOwnerOfProject: (userId, doc) ->
    projectId = doc[SchemaUtils.projectIdProperty]
    # Allow if no project field exists.
    return userId? unless projectId?
    project = Projects.findOne(_id: projectId)
    # Deny if given project doesn't exist.
    return false unless project
    AccountsUtil.isOwnerOrAdmin(project, userId)
  
  setUpProjectAllow: (collection) ->
    allowOwnerOfProject = @allowOwnerOfProject.bind(@)
    collection.allow
      insert: allowOwnerOfProject
      update: allowOwnerOfProject
      remove: allowOwnerOfProject

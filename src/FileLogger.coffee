FileLogger =

  log: (data, args) ->
    df = Q.defer()
    env = Environment.get()
    # Don't log files unless we are in production.
    return false unless env == 'development'
    log(data, args)

log = (data, args) ->
  filename = 'log' + Dates.toIdentifier(moment()) + '.json'
  strData = if Types.isString(data) then data else JSON.stringify(data)
  filePath = FileUtils.writeToTempFile(filename, strData)
  Logger.info('Wrote log to', filePath)
  filePath

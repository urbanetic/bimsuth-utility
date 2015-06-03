class TaskRunner

  constructor: (options) ->
    @options = Setter.merge({
      runDuration: 2000
      waitDuration: 100
    }, options)
    @runQueue = new DeferredQueue()
    @bufferQueue = []
    @status == 'idle'
    @reset()

  add: (callback) ->
    unless callback then throw new Error('Callback not defined')
    @bufferQueue.push(callback)

  run: ->
    if @runDf
      return @runDf.promise
    @runDf = Q.defer()
    if @pauseDf
      @pauseDf.resolve()
      @pauseDf = null

    @status = 'running'
    @_deferWait()
    runNext = Meteor.bindEnvironment =>
      if @bufferQueue.length == 0
        Logger.debug('Task runner complete')
        @runDf.resolve()
        @reset()
        return
      callback = @bufferQueue.shift()
      @runQueue.add(callback).fin(runNext)
    runNext()

    @runDf.promise

  _deferWait: ->
    runDuration = @options.runDuration
    Logger.debug('Task runner running for ' + runDuration + 'ms...')
    @waitHandle = setTimeout (Meteor.bindEnvironment => @_wait()), @options.runDuration

  _wait: ->
    waitDuration = @options.waitDuration
    Logger.debug('Task runner ready to wait...')
    wait = =>
      Logger.debug('Task runner waiting for ' + waitDuration + 'ms...')
      @waitDf = Q.defer()
      onDone = Meteor.bindEnvironment =>
        @_deferWait()
        @waitDf.resolve()
      setTimeout(onDone, waitDuration)
      @waitDf.promise
    @bufferQueue.unshift(wait)

  pause: ->
    if @pauseDf
      return @pauseDf.promise
    Logger.debug('Task runner pausing...')
    @pauseDf = Q.defer()
    @status == 'pausing'
    pause = =>
      # If the pause was cancelled, ignore this callback.
      return unless @pauseDf
      @status = 'paused'
      @pauseDf.promise
    @bufferQueue.unshift(pause)
    clearTimeout(@waitHandle)

  reset: ->
    @status == 'idle'
    _.each ['runDf', 'waitDf'], (name) =>
      df = @[name]
      if df && Q.isPending(df.promise)
        df.reject('Task runner reset')
      @[name] = null
    clearTimeout(@waitHandle)

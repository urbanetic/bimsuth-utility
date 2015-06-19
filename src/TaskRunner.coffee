class TaskRunner

  constructor: (options) ->
    @options = Setter.merge({
      runDuration: 2000
      waitDuration: 100
    }, options)
    @runQueue = new DeferredQueue()
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

    # NOTE: Uses system time instead of timers to prevent locking up during synchronous tasks.
    startTime = null
    runsTime = 0
    lastTaskIsWait = false
    runNext = Meteor.bindEnvironment =>

      if startTime? && !lastTaskIsWait
        currentTime = new Date().getTime()
        timeDiff = currentTime - startTime
        runsTime += timeDiff
        if runsTime >= @options.runDuration
          Logger.debug('Task runner ran for', runsTime, 'ms')
          @_wait()
          lastTaskIsWait = true
          runsTime = 0
      else
        lastTaskIsWait = false
      if @bufferQueue.length == 0
        Logger.debug('Task runner complete')
        @runDf.resolve()
        @reset()
        return
      callback = @bufferQueue.shift()
      startTime = new Date().getTime()
      @runQueue.add(callback).fin =>
        # Prevent running the next task if the runner was paused or reset.
        if @status == 'running' then runNext()
    
    # Running on an empty queue will reset the promise so we need to store a refernece to the
    # promise in case it's removed.
    promise = @runDf.promise
    if @bufferQueue.length == 0 then Logger.warn('No tasks added to runner - aborting')
    runNext()
    promise

  _wait: ->
    waitDuration = @options.waitDuration
    Logger.debug('Task runner ready to wait...')
    wait = =>
      Logger.debug('Task runner waiting for ' + waitDuration + 'ms...')
      @status = 'waiting'
      @waitDf = Q.defer()
      onDone = Meteor.bindEnvironment =>
        @waitDf.resolve()
        @status = 'running'
      setTimeout(onDone, waitDuration)
      @waitDf.promise
    @bufferQueue.unshift(wait)

  pause: ->
    if @pauseDf
      return @pauseDf.promise
    Logger.debug('Task runner pausing...')
    @pauseDf = Q.defer()
    @status = 'pausing'
    pause = =>
      # If the pause was cancelled, ignore this callback.
      return unless @pauseDf
      @status = 'paused'
      @pauseDf.promise
    @bufferQueue.unshift(pause)

  reset: ->
    Logger.debug('Resetting task runner')
    @status = 'idle'
    @runQueue.clear()
    @bufferQueue = []
    _.each ['runDf', 'waitDf'], (name) =>
      df = @[name]
      if df && Q.isPending(df.promise)
        df.reject('Task runner reset')
      @[name] = null
    Logger.debug('Task runner reset')

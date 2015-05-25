class TaskScheduler

  constructor: (options) ->
    options = Setter.merge({
      runDuration: 10000
      waitDuration: 1000
    }, options)
    @queue = new DeferredQueue()
    @pause()

  add: (callback) ->
    @queue.add(callback)

  run: ->
    if @status == 'running'
      throw new Error('Already running')
    if @pauseDf
      @pauseDf.resolve()
      @pauseDf = null
    runDuration = @options.runDuration
    Logger.debug('Task scheduler running for ' + runDuration + 'ms...')
    @handle = setTimeout(@_wait.bind(@), @options.runDuration)
    @queue.waitForAll()

  _wait: ->
    waitDuration = @options.waitDuration
    Logger.debug('Task scheduler waiting for ' + waitDuration + 'ms...')
    waitDf = Q.defer()
    wait = -> @waitDf.promise
    setTimeout(wait, waitDuration)
    @queue.unshift(wait)

  pause: ->
    if @pauseDf
      return @pauseDf.promise
    Logger.debug('Task scheduler pausing...')
    @pauseDf = Q.defer()
    @status == 'pausing'
    pause = -> @pauseDf.promise
    @queue.unshift(pause)
    clearTimeout(@handle)

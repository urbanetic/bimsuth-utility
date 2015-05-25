bindMeteor = Meteor.bindEnvironment.bind(Meteor)

class TaskScheduler

  constructor: (options) ->
    @options = Setter.merge({
      runDuration: 2000
      waitDuration: 100
    }, options)
    @queue = new DeferredQueue()
    @bufferQueue = []
    @status == 'idle'
    @reset()

  add: (callback) ->
    unless callback
      throw new Error('Callback not defined')
    @bufferQueue.push(callback)

  run: ->
    if @runDf
      return @runDf.promise
    @runDf = Q.defer()
    if @pauseDf
      @pauseDf.resolve()
      @pauseDf = null
    runDuration = @options.runDuration
    Logger.debug('Task scheduler running for ' + runDuration + 'ms...')
    @waitHandle = setTimeout (bindMeteor => @_wait()), @options.runDuration

    @status = 'running'
    runNext = bindMeteor =>
      if @bufferQueue.length == 0
        @runDf.resolve()
        @reset()
        return
      callback = @bufferQueue.shift()
      @queue.add(callback).fin(runNext)
    runNext()

    @runDf.promise

  _wait: ->
    waitDuration = @options.waitDuration
    Logger.debug('Task scheduler waiting for ' + waitDuration + 'ms...')
    wait = =>
      @waitDf = Q.defer()
      setTimeout (=> @waitDf.resolve()), waitDuration
      @waitDf.promise
    @bufferQueue.unshift(wait)

  pause: ->
    if @pauseDf
      return @pauseDf.promise
    Logger.debug('Task scheduler pausing...')
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
        df.reject('Task scheduler reset')
      @[name] = null
    clearTimeout(@waitHandle)

class ItemBuffer

  constructor: (args) ->
    @_size = args.size
    unless Numbers.isDefined(@_size) then throw new Error('Must provide size')
    if @_size <= 0 then throw new Error('Size must be > 0')
    @_reset()

  add: (item) ->
    @_buffer.push(item)
    if @_buffer.length >= @_size then @flush()

  getItems: -> _.toArray(@_buffer)

  flush: ->
    _.each @_waitCallbacks, (callback) => callback(@getItems())
    @_buffer = []

  _reset: ->
    @_buffer = []
    @_waitCallbacks = []

  wait: (callback) ->
    unless Types.isFunction(callback) then throw new Error('Must provide callback')
    @_waitCallbacks.push(callback)

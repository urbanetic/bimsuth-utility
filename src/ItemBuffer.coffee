class ItemBuffer

  constructor: (args) ->
    @_maxSize = args.size
    unless Numbers.isDefined(@_maxSize) then throw new Error('Must provide size')
    if @_maxSize <= 0 then throw new Error('Size must be > 0')
    @_reset()
    @_waitCallbacks = []

  add: (id, item) ->
    if @_buffer[id]? then Logger.warn('Replacing ItemBuffer item', id, @_buffer[id], item)
    if @_size + 1 > @_maxSize then @flush()
    @_buffer[id] = item
    @_size++

  remove: (id) ->
    return unless @_buffer[id]?
    delete @_buffer[id]
    @_size--

  getItems: -> _.clone(@_buffer)

  flush: ->
    _.each @_waitCallbacks, (callback) => callback(@getItems())
    @_reset()

  _reset: ->
    @_size = 0
    @_buffer = {}

  wait: (callback) ->
    unless Types.isFunction(callback) then throw new Error('Must provide callback')
    @_waitCallbacks.push(callback)

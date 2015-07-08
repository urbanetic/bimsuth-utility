request = Npm.require('request')
stream = Npm.require('stream')
concat = Npm.require('concat-stream')

Request =

  call: (opts) ->
    opts = @mergeOptions(opts)
    Promises.runSync (done) ->
      request opts, (err, res, body) ->
        done(err, body)

  buffer: (opts) ->
    opts = @mergeOptions(opts)
    Promises.runSync (done) ->
      receiveBuffer = (buffer) -> done(null, buffer)
      concatStream = concat(receiveBuffer)
      readStream = request(opts)
      readStream.on 'error', (err) -> done(err, null)
      readStream.pipe(concatStream)

  json: (opts) ->
    body = @call(opts)
    if body == ''
      body = null
    else
      try
        body = JSON.parse(body)
      catch e
        console.log('Failed parsing to JSON', body, e)
        throw e
    body

  mergeOptions: (opts) ->
    Setter.merge({
      jar: true
    }, opts)

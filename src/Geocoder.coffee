NodeGeocoder = Npm.require('node-geocoder')

{hereAppId, hereAppCode} = Meteor.settings

unless hereAppId? and hereAppCode?
  Logger.warn('Geocoder needs hereAppId and hereAppCode')
  return

options =
  provider: 'here'
  appId: hereAppId
  appCode: hereAppCode

geocoder = NodeGeocoder(options)

Geocoder =

  # API only allows a single request at a time.
  # _queue: new DeferredQueue()
  _runner: new TaskRunner
    waitDuration: 10

  geocode: (address, options) ->
    address = address?.trim()
    return Q.reject('Address not provided') if _.isEmpty(address)

    options = Setter.merge
      triesLeft: 3
      tryDelay: 2000
    , options

    df = Q.defer()

    runCallback = =>
      runDf = Q.defer()
      @_runner.add =>
        @_geocode(address, options).then(
          (results) ->
            df.resolve(results)
            runDf.resolve(results)
          (err) =>
            # Wait for a given delay if we exceed the API query limit.
            if Types.isString(err) and err.indexOf('OVER_QUERY_LIMIT') >= 0
              options.triesLeft--
              if options.triesLeft <= 0
                msg = "Exceeded API limit and number of tries: #{address}"
                runDf.reject(msg)
                return df.reject(msg)
              @_runner.wait(options.tryDelay)
              runCallback()
              runDf.reject(err)
            else
              runDf.reject(err)
              df.reject(err)
        )
        runDf.promise
      @_runner.run()
      runDf.promise

    runCallback()
    df.promise

  _geocode: (address, options) ->
    df = Q.defer()
    geocoder.geocode address, (err, data) =>
      if err? or _.isEmpty(data)
        msg = "Failed to geocode: #{address}"
        err ?= msg
        df.reject(err)
      else
        df.resolve(data)
    df.promise

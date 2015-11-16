AWS = Package['peerlibrary:aws-sdk'].AWS
return unless AWS?

env = process.env

AWS_ACCESS_KEY_ID = env.AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY = env.AWS_SECRET_ACCESS_KEY

if AWS_ACCESS_KEY_ID? && AWS_SECRET_ACCESS_KEY?
  AWS.config.update
    accessKeyId: AWS_ACCESS_KEY_ID
    secretAccessKey: AWS_SECRET_ACCESS_KEY
else
  Logger.error('AWS configuration missing')

s3 = new AWS.S3()

# Utility methods for using Amazon S3.
S3Utils =

  # A cache of the downloaded files.
  _cache: {}
  
  # Returns a promised buffer containing the data in the given bucket and key.
  #  * `bucket` - The name of the S3 bucket.
  #  * `key` - The name of the file.
  #  * `options.cache` - Whether to use the cache for the request. Defaults to true. If false,
  #                      the result is still cached for next use.
  download: (bucket, key, options) ->
    shouldCache = options?.cache != false
    if shouldCache
      df = @_cache[bucket + key]
      return df.promise if df
    df = Q.defer()
    @_cache[bucket + key] = df
    try
      s3.getObject {Bucket: bucket, Key: key}, (err, result) =>
        if err
          df.reject(err)
          delete @_cache[bucket + key]
        else
          df.resolve(result.Body)
    catch err
      df.reject(err)
    df.promise

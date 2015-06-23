ParamUtils =
  
  prefix: 'parameters'
  rePrefix: /^parameters\./
  _formatter: null

  addPrefix: (id) ->
    if @rePrefix.test(id)
      id
    else
      @prefix + '.' + id
  
  removePrefix: (id) -> id.replace(@rePrefix, '')
  
  hasPrefix: (id) -> @.rePrefix.test(id)
  
  getParamSchema: (paramId) ->
    paramId = @removePrefix(paramId)
    Entities.ParametersSchema.schema(paramId) ? Projects.ParametersSchema.schema(paramId)
  
  getLabel: (paramId) ->
    schema = @getParamSchema(paramId)
    label = schema.label
    return label if label?
    label = _.last(paramId.split('.'))
    Strings.toTitleCase(Strings.toSpaceSeparated(label))

  getNumberFormatter: -> @_formatter

  getParamNumberFormatter: _.memoize (paramId) ->
    paramSchema = @getParamSchema(paramId)
    unless paramSchema.type == Number
      return Q.when(null)
    decimalPoints = if paramSchema.decimal then paramSchema.decimalPoints ? 2 else 0
    format = (value, args) =>
      args = _.extend({minSigFigs: decimalPoints, maxSigFigs: decimalPoints}, args)
      @_formatter.round(value, args)
    format

requirejs ['atlas/util/NumberFormatter'], (NumberFormatter) ->
  ParamUtils._formatter = new NumberFormatter()

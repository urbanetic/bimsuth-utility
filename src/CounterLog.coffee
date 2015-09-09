class CounterLog

  constructor: (args) ->
    @options = Setter.merge
      bufferSize: 1
      value: 0
      label: 'Counter log'
    , args
    @total = @options.total
    unless Types.isNumber(@total) and @total >= 0 then throw new Error('Invalid total: ' + @total)
    @value = @options.value
    unless Types.isNumber(@value) then throw new Error('Invalid value: ' + @value)
    @log()

  increment: (amount = 1) ->
    @value += amount
    if @value >= @total
      @value == @total
      @log()
    else if @value % @options.bufferSize == 0
      @log()

  log: -> Logger.info("#{@options.label}: #{@value}/#{@total}")    

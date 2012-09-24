#
# ryu is a simple control-flow library for node.js
#

# ## LICENSE ##
# The MIT License (MIT)
#  Copyright (c) 2012 Shogo Kawase <shogo@studiofly.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# ## ryu.chain() ##
#     Create an object has method `build`.
#       @param {String} [chainName] - Optional. Name of chain.
#                                     default is 'nameless'.
#       @returns {Object} - An object has method `build`
exports.chain = (chainName = 'nameless') ->
  #### build(): Function
  #     Build chained function contains specified step functions.
  #       @public
  #       @param {Function} steps... - Required. Functions to execute.
  #       @returns {Function} - Function that executes chained functions.
  build: (steps...) ->
    if steps.length == 0
      throw new ChainError 'Cannot create empty chain.'
    for step in steps
      if typeof step != 'function'
        throw new TypeError "#{typeof step} is not a function."
    callback = steps.pop()
    chain = new Chain(chainName, steps, callback)
    return (args...) -> chain.start args

# ## Context ##
#     Context for step function.
class Context
  #### name
  #     Name of chain.
  #       @public
  #       @type String
  name: null

  #### data
  #     An object to store any objects in step functions.
  #       @public
  #       @type Object
  data: null

  #### step
  #     Index of current step.
  #       @public
  #       @type Number
  step: null

  #### private members
  _chain: null
  _state: null

  #### constructor()
  #       @param {Chain}  chain - Required. An instance of Chain.
  #       @param {Object} state - Required. An object stores state of step.
  constructor: (chain, state) ->
    @name = chain.name
    @data = {}
    @step = 0
    @_chain = chain
    @_state = state

  #### next(): void
  #     Start next step when current step completed.
  #       @public
  #       @param {Object} [args...]: Optional. Arguments for next step.
  next: (args...) ->
    state = @_checkState()
    if state.asyncCalled
      throw new ChainError "async() already called at chain `#{@_chain.name}`."
    state.nextCalled = true
    state.args = args
    return

  #### last(): void
  #     Start last step when current step completed.
  #       @public
  #       @param {Object} [args...] - Optional. Arguments for next step.
  last: (args...) ->
    state = @_checkState()
    if state.asyncCalled
      throw new ChainError "async() already called at chain `#{@_chain.name}`."
    state.lastCalled = true
    state.args = args
    return

  #### async(): Function
  #     Create callback function for asynchronous function.
  #       @public
  #       @param {Object} [object] - Optional.
  async: (options) ->
    state = @_checkState()
    state.asyncCalled = true
    index = state.asyncCount++
    options = @_createAsyncOptions options
    return (err, args...) =>
      if err
        return @_chain.onFailure @, err
      unless options.useArray
        args = args[options.index]
      state.args[index] = args
      if ++state.asyncCompleteCount >= state.asyncCount
        @_chain.wait @, state
      return

  #### _checkState(): Object
  #       @private
  _checkState: ->
    state = @_state
    if state.nextCalled
      throw new ChainError "next() already called at chain `#{@_chain.name}`."
    if state.lastCalled
      throw new ChainError "last() already called at chain `#{@_chain.name}`."
    return state

  #### _createAsyncOptions(): Object
  #       @private
  _createAsyncOptions: (options) ->
    if options is null or options is undefined then return {index: 0}
    if typeof options is 'number' then return {index: options}
    if options.useArray then return {useArray: true}
    return {index: parseInt(options.index ? 0)}

# ## Chain ##
#     Chained functions container
class Chain
  name: null
  _steps: null
  _callback: null
  _context: null

  constructor: (name, steps, callback)->
    @name = name
    @_steps = steps
    @_callback = callback

  start: (args) ->
    state = {}
    context = new Context @, state
    @runWithArgs context, state, args

  run: (context, state) ->
    @runWithArgs context, state, state.args
    return

  runWithArgs: (context, state, args) ->
    process.nextTick =>
      @resetState state
      steps = @_steps
      if context.step == steps.length
        return @onSuccess context, args
      try
        steps[context.step].apply context, args
        context.step++
        state.stepCompleted = true
        if state.lastCalled
          @onSuccess context, state.args
        else if state.nextCalled
          @run context, state
        else if not state.asyncCalled
          throw new ChainError 'Cannot chain functions without call `next` or `last` or `async`.'
      catch err
        @onFailure context, err
      return
    return

  resetState: (state) ->
    state.args = []
    state.lastCalled = false
    state.nextCalled = false
    state.asyncCalled = false
    state.asyncCount = 0
    state.asyncCompleteCount = 0
    state.stepCompleted = false
    return state

  wait: (context, state) ->
    unless state.stepCompleted
      process.nextTick => @wait context, state
    else
      @run context, state
    return

  onSuccess: (context, args) ->
    if Array.isArray(args) && args.length > 0
      args.unshift undefined
    else
      args = undefined
    @onComplete context, @_callback, args
    return

  onFailure: (context, err) ->
    @onComplete context, @_callback, [err]
    return

  onComplete: (context, callback, args) ->
    process.nextTick -> callback.apply context, args
    return

# ## ryu.ChainError ##
#     An error object named `ChainError`
ChainError = exports.ChainError = (msg, cause) ->
  Error.call @, msg
  if msg != undefined then @message = msg
  if cause != undefined then @cause = cause
ChainError.prototype = (->
  Inheritor = ->
  Inheritor.prototype = Error.prototype
  new Inheritor()
)()
ChainError::constructor = ChainError
ChainError::name = 'ChainError'
ChainError::message = ''

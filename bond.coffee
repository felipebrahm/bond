isFunction = (obj) ->
  typeof obj == 'function'

createThroughSpy = (getValue, bondApi) ->
  spy = ->
    args = Array::slice.call(arguments)
    spy.calledArgs[spy.called] = args
    spy.called++

    result = getValue.apply(this, args)

    isConstructor = (this instanceof arguments.callee)
    return this if isConstructor and typeof result != 'object'
    result

  enhanceSpy(spy, getValue, bondApi)

createReturnSpy = (getValue, bondApi) ->
  spy = ->
    args = Array::slice.call(arguments)
    spy.calledArgs[spy.called] = args
    spy.called++

    getValue.apply(this, args)

  enhanceSpy(spy, getValue, bondApi)

createAnonymousSpy = ->
  returnValue = null

  spy = ->
    args = Array::slice.call(arguments)
    spy.calledArgs[spy.called] = args
    spy.called++

    returnValue

  enhanceSpy(spy)

  spy.return = (newReturnValue) ->
    returnValue = newReturnValue
    spy
  spy

enhanceSpy = (spy, original, bondApi) ->
  spy.prototype = original?.prototype
  spy.called = 0
  spy.calledArgs = []
  spy.calledWith = (args...) ->
    return false if !spy.called
    lastArgs = spy.calledArgs[spy.called-1]
    arrayEqual(args, lastArgs)

  spy[k] = v for k, v of bondApi if bondApi

  spy

arrayEqual = (A, B) ->
  for a, i in A
    b = B[i]
    return false if a != b

  true


nextTick = do ->
  return process.nextTick if isFunction(process?.nextTick)
  return setImmediate if setImmediate? && isFunction(setImmediate)

  (fn) ->
    setTimeout(fn, 0)


allStubs = []
registered = false
registerCleanupHook = ->
  return if registered

  after = afterEach ? testDone ? QUnit?.testDone ? bond.cleanup ? ->
    throw new Error('bond.cleanup must be specified if your test runner does not use afterEach or testDone')

  after ->
    for stubRestore in allStubs
      stubRestore()
    allStubs = []

  registered = true

bond = (obj, property) ->
  registerCleanupHook()
  return createAnonymousSpy() if arguments.length == 0

  previous = obj[property]

  registerRestore = ->
    allStubs.push restore
  restore = ->
    obj[property] = previous

  to = (newValue) ->
    registerRestore()

    if isFunction(newValue)
      newValue = createThroughSpy(newValue, this)

    obj[property] = newValue
    obj[property]

  returnMethod = (returnValue) ->
    registerRestore()
    returnValueFn = -> returnValue
    obj[property] = createReturnSpy(returnValueFn, this)
    obj[property]

  asyncReturn = (returnValues...) ->
    to (args..., callback) ->
      if !isFunction(callback)
        throw new Error('asyncReturn expects last argument to be a function')

      nextTick ->
        callback(returnValues...)

  through = ->
    obj[property] = createThroughSpy(previous, this)
    obj[property]

  {
    'to': to
    'return': returnMethod
    'asyncReturn': asyncReturn
    'through': through
    'restore': restore
  }

window.bond = bond if window?
module.exports = bond if module?.exports

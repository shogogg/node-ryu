chai = require 'chai'
expect = chai.expect
describe = global.describe
it = global.it

ryu = require '../lib/ryu'
ChainError = ryu.ChainError

describe 'ryu', ->
  it 'expect to be an object', -> expect(ryu).to.be.an 'object'
  it 'expect to have a property `chain`', -> expect(ryu).to.have.a.property 'chain'
  describe '#chain', ->
    it 'expect to be a function', ->
      expect(ryu.chain).to.be.a 'function'
    it 'expect to returns an object has a property `build`', ->
      chain = ryu.chain()
      expect(chain).to.be.an 'object'
      expect(chain).to.have.a.property 'build'

describe 'ryu.chain().build', ->
  chain = ryu.chain()
  it 'expect to be a function', -> expect(chain.build).to.be.a 'function'
  it 'expect to throw ChainError when the steps is not present', ->
    expect(-> chain.build()).to.throw ChainError, 'Cannot create empty chain.'
  it 'expect to throw TypeError when the one of steps is not a function', ->
    expect(-> chain.build 0).to.throw TypeError, 'number is not a function'
    expect(-> chain.build (->), 'foobar')
      .to.throw TypeError, 'string is not a function'
    expect(-> chain.build (->), (->), {})
      .to.throw TypeError, 'object is not a function'
    expect(-> chain.build (->), (->), (->), false)
      .to.throw TypeError, 'boolean is not a function'
  it 'expect to returns a function', ->
    expect(-> chain.build (-> 0)).to.be.a 'function'

describe 'chain', ->
  it 'expect to chain functions with `next`', (done) ->
    ryu.chain().build(
      (text) ->
        expect(text).to.equal '1st'
        @next('2nd')
      (text) ->
        expect(text).to.equal '2nd'
        @next()
      (text) ->
        expect(text).to.be.an 'undefined'
        @next('3rd')
      (text) ->
        expect(text).to.equal '3rd'
        @next()
      (err) ->
        if err then throw err
        done()
    )('1st')
  it 'expect to chain functions with `last`', (done) ->
    ryu.chain().build(
      (text) ->
        expect(text).to.equal '1st'
        @last('2nd')
      (text) -> @last()
      (text) -> @last('3rd')
      (text) ->
        expect(text).to.equal '2rd'
        @last()
      (err) ->
        if err then throw err
        done()
    )('1st')
  it 'expect to chain functions with `async`', (done) ->
    fn = (callback) ->
      setTimeout (-> callback(undefined, 'a', 'b', 'c')), 10
    chain = ryu.chain('chain-1').build(
      (callback) ->
        next = @async()
        @data.callback = callback
        setTimeout (-> next(undefined, 'x')), 20
      (text) ->
        expect(text).to.equal 'x'
        fn @async(0)
        fn @async(1)
        fn @async(2)
        fn @async({index: 0})
        fn @async({index: 1})
        fn @async({index: 2})
        fn @async({useArray: true, index: 1})
      (a, b, c, aa, bb, cc, arr) ->
        expect(a).to.equal 'a'
        expect(b).to.equal 'b'
        expect(c).to.equal 'c'
        expect(aa).to.equal 'a'
        expect(bb).to.equal 'b'
        expect(cc).to.equal 'c'
        expect(Array.isArray arr).to.be.true
        expect(arr[0]).to.equal 'a'
        expect(arr[1]).to.equal 'b'
        expect(arr[2]).to.equal 'c'
        @next()
      (err) -> @data.callback err
    )
    ryu.chain().build(
      ->
        chain @async()
        chain @async()
        chain @async()
      (err) ->
        if err then throw err
        done()
    )()
  it 'expect to throw ChainError when do not call any methods in `next`, `last`, `async`', (done) ->
    ryu.chain().build(
      -> 'foo'
      -> 'bar'
      (err) ->
        expect(err).to.be.an.instanceOf ChainError
        expect(err).to.have.property 'message', 'Cannot chain functions without call `next` or `last` or `async`.'
        done()
    )()
  it 'expect to throw ChainError when step method called duplicately', (done) ->
    functions = []
    fn = (a, b) -> ->
      next = @async()
      ryu.chain("#{a}-#{b}").build(
        -> [@[a](), @[b]()]
        (err) ->
          expect(err).to.be.an.instanceOf ChainError
          expect(err).to.have.property 'message', "#{a}() already called at chain `#{a}-#{b}`."
          next()
      )()
    for a in ['next', 'last', 'async']
      for b in ['next', 'last', 'async']
        if a == 'async' and b == 'async' then continue
        functions.push fn(a, b)
    functions.push -> done()
    ryu.chain().build.apply(null, functions)()

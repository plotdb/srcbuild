require! <[fs path fs-extra]>
require! <[../aux ../adapter]>

basebuild = (opt={}) ->
  @init opt
  @

basebuild.prototype = Object.create(Object.prototype) <<< do
  # abstract functions for defined by user
  is-supported: (file) ->
  get-dependencies: (file) ->
  build: (files) ->
  purge: (files) ->
  resolve: (file) ->

  init: (opt={}) ->
    @init-vars opt
    @init-adapter opt
    @

  init-vars: (opt={}) ->
    @log = opt.logger or aux.logger
    @base = opt.base or @base or '.'
    @srcdir = path.normalize(path.join(@base, opt.srcdir or @srcdir or '.'))
    @desdir = path.normalize(path.join(@base, opt.desdir or @desdir or '.'))

  init-adapter: (opt={}) ->
    @adapter = new adapter do
      base: @srcdir
      get-dependencies: ~> @get-dependencies it
      is-supported: ~> @is-supported it
      build: (files) ~> @build files
      purge: (files) ~> @purge files
      resolve: (file) ~> @resolve file
    @adapter.init!
  get-adapter: -> @adapter

module.exports = basebuild

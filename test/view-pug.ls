require! <[fs path assert]>
{test} = require 'node:test'
viewengine = require '../src/view/pug'
{quiet, tmpdir, write, touch} = require './aux'

# see test/pug.ls: fixtures avoid `doctype` so lib.pug is not injected.
mk = (root, env = \development) ->
  engine = viewengine {
    base: root, logger: (quiet <<< {debug: ->}), srcdir: 'src/pug', desdir: 'static', viewdir: '.view'
  }
  return (src) -> new Promise (res, rej) ->
    engine src, {
      settings: {env, 'view cache': env != \development}
      basedir: path.join(root, 'src/pug')
    }, (e, html) -> if e => rej e else res html

layout = (root) ->
  write root, {
    'src/pug/base.pug': 'div\n  block body\n'
    'src/pug/index.pug': 'extends base.pug\nblock body\n  p one\n'
  }

test 'a page is re-rendered when only the layout it extends changed', ->
  root = layout tmpdir!
  render = mk root
  src = path.join(root, 'src/pug/index.pug')
  Promise.resolve!
    .then -> render src
    .then (html) ->
      assert.ok ~html.index-of('<div>'), "layout applied: #html"
      # only the layout moves. index.pug's own mtime stays where it was, which is what
      # used to leave the precompiled view in place.
      write root, {'src/pug/base.pug': 'section\n  block body\n'}
      touch path.join(root, 'src/pug/base.pug')
      render src
    .then (html) ->
      assert.ok ~html.index-of('<section>'), "layout change must show up: #html"

test 'a dependency change is ignored when not in development', ->
  root = layout tmpdir!
  render = mk root, \production
  src = path.join(root, 'src/pug/index.pug')
  Promise.resolve!
    .then -> render src
    .then ->
      write root, {'src/pug/base.pug': 'section\n  block body\n'}
      touch path.join(root, 'src/pug/base.pug')
      render src
    .then (html) ->
      assert.ok ~html.index-of('<div>'), "production keeps serving the built view: #html"

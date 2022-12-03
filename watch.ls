require! <[fs path express ./dist/i18n @plotdb/block jsdom]>
# running a local watcher for testing purpose.

lib = path.dirname(fs.realpathSync __filename.replace(/\(js\)$/, ''))
main = require "#lib/dist/main"

dom = new jsdom.JSDOM "<DOCTYPE html><html><body></body></html>"
[win, doc] = [dom.window, dom.window.document]
block.env win

mgr = new block.manager registry: (d) ->
  path = d.path or if d.type == \block => \index.html
  else if d.type == \js => \index.min.js
  else \index.min.css
  if d.type == \block => return "web/static/block/#{d.name}/#{d.version or \main}/#path"
  return "web/static/assets/lib/#{d.name}/#{d.version or \main}/#path"

server =
  init: (opt={})->
    @app = app = express!
    cwd = process.cwd!
    app.use \/, express.static \web/static
    console.log "[Server] Express Initialized in #{app.get \env} Mode".green
    server = app.listen ->
      delta = if opt.start-time => "( takes #{Date.now! - opt.start-time}ms )" else ''
      console.log "[SERVER] listening on port #{server.address!port} #delta".cyan

i18n({enabled:true})
  .then (i18n) ->
    ret = main.lsp {
      base: <[web alt]>
      i18n
      bundle:
        config-file: 'web/bundle.json'
        relative-path: true
        manager: mgr
    }
    server.init!


# sample bundling:
# ret = main.lsp {i18n, bundle: {configFile: 'bundle.json'}}
# sample bundle.json:
# {"js": { "test": [ "web/static/js/index.js" ] } }

# on demand build sample
/*
setTimeout (->
  ret.demand 'web/.view/a.js'
  ret.demand 'web/static/js/index.min.js'
  ret.demand 'web/static/css/index.min.css'
), 2000
*/


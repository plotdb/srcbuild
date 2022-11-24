require! <[fs path express ./dist/i18n]>
# running a local watcher for testing purpose.

lib = path.dirname(fs.realpathSync __filename.replace(/\(js\)$/, ''))
main = require "#lib/dist/main"

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
    ret = main.lsp {base: <[web alt]>, i18n, bundle: {config-file: 'web/bundle.json', relative-path: true}}
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


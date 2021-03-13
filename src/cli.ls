require! <[fs path ./i18n]>

lib = path.dirname fs.realpathSync __filename
main = require "#lib/main"
i18n({enabled:true})
  .then (i18n) ->
    ret = main.lsp {i18n}

# on demand build sample
/*
setTimeout (->
  ret.demand 'web/.view/a.js'
  ret.demand 'web/static/js/index.min.js'
  ret.demand 'web/static/css/index.min.css'
), 2000
*/

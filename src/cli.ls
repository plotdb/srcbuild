require! <[fs path ./i18n]>

lib = path.dirname fs.realpathSync __filename
main = require "#lib/main"
i18n({enabled:true})
  .then (i18n) -> main.lsp {i18n}

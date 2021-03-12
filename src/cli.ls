require! <[fs path]>

lib = path.dirname fs.realpathSync __filename
main = require "#lib/main"
main!

require! <[path crypto]>
require! <[./aux]>
fs = require "fs-extra"

# content addressing for built files. two modes:
#
#   filename ( default )  also write `<name>.<hash>[.min].<ext>`; pages point at that.
#                         a url names exactly one byte sequence, so it can be served
#                         immutable. old files have to be expired, and html older than
#                         that gets a 404 unless nginx falls back to the plain name.
#   query                 leave one file and point at `<name>.min.js?v=<hash>`. nothing
#                         accumulates and nothing 404s, but stale html silently gets
#                         whatever the file holds now, and some CDNs ignore the query
#                         when caching.
#
# either way the plain name is always written and always current: it is what already
# deployed html points at, the fallback for a page rendered before the first build, and
# the target of the nginx fallback in filename mode.
#
#     "<plain url>" -> {url: "<addressed url>", generations: [{files, at}, ...]}
#
# keyed by the *url*, because that is what a pug page asks with. the manifest is shared
# by every builder of one base.
hashstore = (o = {}) ->
  @base = o.base or '.'
  # urls are relative to the web root, not to any single builder's desdir.
  @root = path.normalize(o.root or path.join(@base, 'static'))
  @fn = o.manifest or hashstore.manifest-path(@base)
  # how long an already-rendered page keeps working. it holds the url of whatever was
  # current when it was rendered, so evicting that file 404s its script.
  #
  # `keep` alone answers the wrong question - three rebuilds can be three hours or
  # three months, while the real risk is "how long can a browser tab stay open".
  # so a generation has to be BOTH beyond `keep` and older than `keep-days` before it
  # is deleted. these files are small; being generous costs almost nothing.
  @mode = if o.mode == \query => \query else \filename
  @keep = if o.keep? => that else 3
  # default 0: no age floor. a client holding html across several deploys is already
  # exposed to backend api drift, so the answer to that is a "site updated, reload"
  # prompt, not keeping every artefact for a month. raise this if you would rather
  # spend disk than show that prompt.
  @keep-days = if o.keep-days? => that else 0
  @log = o.logger or aux.logger
  @evthdr = {}
  @load!
  @

hashstore.manifest-path = (base = '.') -> path.join(base, '.bundle-dep', 'manifest.json')

# generations used to be plain arrays of filenames. an entry written by an older
# version has no timestamp; treat it as ancient so it ages out on the next rebuild.
hashstore.normalize-gen = (g) ->
  if Array.isArray(g) => {files: g, at: 0}
  else {files: (g.files or []), at: (g.at or 0)}

# insert the hash before the trailing `[.min].<ext>`:
#   vendor.min.js -> vendor.<hash>.min.js      index.css -> index.<hash>.css
hashstore.hashed-name = (name, hash) ->
  parts = name.split '.'
  if parts.length < 2 => return "#name.#hash"
  at = if parts.length > 2 and parts[* - 2] == \min => parts.length - 2 else parts.length - 1
  parts.splice at, 0, hash
  return parts.join '.'

hashstore.prototype = Object.create(Object.prototype) <<< do
  on: (n, cb) -> (if Array.isArray(n) => n else [n]).map (n) ~> @evthdr.[][n].push cb
  fire: (n, ...v) -> for cb in (@evthdr[n] or []) => cb.apply @, v

  url-of: (file) -> '/' + path.relative(@root, path.normalize file).split(path.sep).join('/')

  load: ->
    @manifest = {}
    if !fs.exists-sync(@fn) => return
    try
      @manifest = JSON.parse(fs.read-file-sync(@fn).toString!) or {}
    catch e
      @log.error "parse error of hash manifest #{@fn}".red
      @manifest = {}

  # written synchronously and before the caller is told the url changed: a page
  # rendered right after a rebuild must not read a manifest that is still behind.
  save: ->
    try
      fs.output-file-sync @fn, JSON.stringify(@manifest, null, 2)
    catch e
      @log.error "failed to write #{@fn}: #{e.message}".red

  # the content-addressed url for a plain url, or null if we have never built it.
  get: (url) -> (@manifest[url] or {}).url or null

  # the file has not changed but we have no record of it ( the manifest was wiped while
  # the outputs survived ). adopt it instead of silently falling back forever.
  ensure: (file) ->
    if @get(@url-of file) => return null
    if !fs.exists-sync(file) => return null
    @put file, fs.read-file-sync(file)

  # what the plain url resolves to on disk, for an nginx-less consumer. filename mode
  # only; in query mode the plain file is the only file.
  hashed-file-of: (url) ->
    if @mode == \query => return null
    if !(e = @manifest[url]) or !e.generations or !e.generations.0 => return null
    return hashstore.normalize-gen(e.generations.0).files.0 or null

  put: (file, code) ->
    url = @url-of file
    hash = crypto.create-hash \md5 .update(code) .digest \hex .substring 0, 12
    if @mode == \query => return @put-query url, hash
    hashed = path.join(path.dirname(file), hashstore.hashed-name(path.basename(file), hash))
    entry = {url: @url-of(hashed)}
    prev = @manifest[url] or {}
    changed = prev.url != entry.url

    now = Date.now!
    cur = {files: [hashed], at: now}
    olds = (prev.generations or []).map hashstore.normalize-gen
    gens = if changed => [cur] ++ olds else [cur] ++ olds.slice(1)
    # keep the newest `keep`, plus anything younger than `keep-days` regardless of count
    cutoff = now - @keep-days * 86400000
    [kept, rest] = [gens.slice(0, @keep), gens.slice(@keep)]
    gens = kept ++ rest.filter (g) -> g.at > cutoff
    dropped = rest.filter (g) -> !(g.at > cutoff)
    alive = new Set([].concat.apply([], gens.map -> it.files))

    try
      fs.output-file-sync hashed, code
      [].concat.apply([], dropped.map -> it.files).filter((f) -> !alive.has f).map (f) ~>
        @log.info "#f expired, deleted."
        try fs.remove-sync f
      @manifest[url] = entry <<< {generations: gens}
      @save!
    catch e
      @log.error "failed to write #hashed: #{e.message}".red
      return null

    if changed =>
      @log.info "#file --> #hashed"
      @fire \change, {url, hashed: entry.url, prev: prev.url or null}
    return {} <<< entry <<< {url: url, hashed: entry.url, changed}

  # query mode: one file, so there is nothing to write and nothing to expire.
  put-query: (url, hash) ->
    entry = {url: "#url?v=#hash"}
    prev = @manifest[url] or {}
    changed = prev.url != entry.url
    @manifest[url] = entry <<< {generations: []}
    @save!
    if changed =>
      @log.info "#url --> #{entry.url}"
      @fire \change, {url, hashed: entry.url, prev: prev.url or null}
    return {} <<< entry <<< {url: url, hashed: entry.url, changed}

  # the file is not going to be rebuilt again ( its source was deleted ). take its
  # copies and its entry with it, or they accumulate for the life of the project.
  drop: (file) ->
    url = @url-of file
    if !(e = @manifest[url]) => return
    delete @manifest[url]
    @save!
    [].concat.apply([], (e.generations or []).map(hashstore.normalize-gen).map -> it.files).map (f) ~>
      if !fs.exists-sync f => return
      @log.info "#f removed with its source."
      try fs.remove-sync f

module.exports = hashstore

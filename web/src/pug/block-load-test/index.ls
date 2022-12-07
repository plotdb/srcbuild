lc = {}
mgr = new block.manager registry: ({ns,name,version,path,type}) ->
  if name == \sample => lc.sample-from-fetch = true
  version = version or 'main'
  path = path or if type == \block => 'index.html' else if type == \js => \index.min.js else \index.min.css
  return if type == \block => "/block/#name/#version/#path"
  else "/assets/lib/#name/#version/#path"

p = if b = document.querySelector 'link[rel=block]' =>
  url = b.getAttribute \href
  mgr.debundle {url}
else Promise.resolve!

p
  .then -> mgr.from {name: \sample}, {root: document.body}
  .then (ret) ->
    if lc.sample-from-fetch =>
      msg = "this block is loaded dynamically through manager, instead of from bundle"
    else
      msg = "this block is loaded from bundle."
    ret.interface.show msg

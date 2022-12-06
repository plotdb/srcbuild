
mgr = new block.manager registry: ({ns,name,version,path,type}) ->
  version = version or 'main'
  path = path or if type == \block => 'index.html' else if type == \js => \index.min.js else \index.min.css
  return if type == \block => "/block/#name/#version/#path"
  else "/assets/lib/#name/#version/#path"

if b = document.querySelector 'link[rel=block]' =>
  url = b.getAttribute \href
  mgr.debundle {url}
    .then ->
      mgr.from {name: \sample}, {root: document.body}

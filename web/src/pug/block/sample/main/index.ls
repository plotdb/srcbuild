module.exports =
  pkg: dependencies: [
    {name: "@loadingio/ldquery", type: \js}
    {name: "ldview", type: \js}
    {name: "ldcover", type: \js}
    {name: "ldcover", type: \css, global: true}
  ]
  interface: -> show: ~> @msg = it; @view.render!
  init: ({ctx, root}) ->
    {ldcover, ldview} = ctx
    @view = new ldview do
      root: root
      text: msg: ({node}) ~> @msg or '-'
    ldcv = new ldcover root: root, resident: true
    ldcv.toggle!

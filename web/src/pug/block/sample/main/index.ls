module.exports =
  pkg: dependencies: [
    {name: "ldcover", type: \js}
    {name: "ldcover", type: \css, global: true}
  ]
  init: ({ctx, root}) ->
    {ldcover} = ctx
    ldcv = new ldcover root: root
    ldcv.get!

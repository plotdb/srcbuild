module.exports =
  pkg: dependencies: [
    {name: "ldloader", type: \js}
    {name: "ldloader", type: \css}
  ]
  init: ({ctx}) ->
    {ldloader} = ctx
    ldld = new ldloader className: 'ldld full'
    ldld.on!

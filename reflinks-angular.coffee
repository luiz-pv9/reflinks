# Register the module the client's app must include from
reflinksModule = @angular.module('reflinks', [])

# The 'reflinksConfig' provider configures how the angular application
# interacts with reflinks.
reflinksModule.provider('reflinks', ->

  # Scope the user might set using the 'setScope' function.
  # When navigating using reflinks, the HTML returned from the server
  # will be compiled against this scope.
  scope = {}

  # Grab a reference to angular injector
  $injector = angular.injector(['ng'])

  # Compiles the specified nodes against the scope
  compileNodes = (nodes) ->
    $injector.invoke(['$compile', ($compile) ->
      console.log("GATOOOO!!!!!!")
    ])

  # Helper function to register the specified url as 'compilable'.
  @compileWhen = (url) ->
    Reflinks.when(url, (res) ->
      ev = res.ev
      if ev.data and ev.data.nodes
        compileNodes ev.data.nodes
    )

  # Scope that the contents of the page will be compiled against.
  @compileWith = (_scope) -> scope = _scope

  @$get = [() -> console.log("Função get")]

  # Prevents coffee script returning only the $get method
  return @
)

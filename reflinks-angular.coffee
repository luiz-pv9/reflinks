# Register the module the client's app must include from
reflinksModule = @angular.module('reflinks', [])

# The 'reflinksConfig' provider configures how the angular application
# interacts with reflinks.
reflinksModule.provider('reflinks', ->

  # Scope the user might set using the 'setScope' function.
  # When navigating using reflinks, the HTML returned from the server
  # will be compiled against this scope.
  scope = {}

  # Helper function to register the specified url as 'compilable'.
  @compileWhen = (url) ->
    Reflinks.when(url, (title, nodes) ->
      console.log("called!!!")
      console.log(title, nodes)
    )

  # Scope that the contents of the page will be compiled against.
  @compileWith = (_scope) -> scope = _scope

  @$get = [() -> console.log("Função get")]

  # Prevents coffee script returning only the $get method
  return @
)

# Register the module the client's app must include from
reflinksModule = @angular.module('reflinks', [])

# The 'reflinksConfig' provider configures how the angular application
# interacts with reflinks.
reflinksModule.provider('reflinksConfig', ->

  # Scope the user might set using the 'setScope' function.
  # When navigating using reflinks, the HTML returned from the server
  # will be compiled against this scope.
  scope = {}

  # Scope that the contents of the page will be compiled against.
  @setScope = (_scope) -> scope = _scope

  @$get = [() -> console.log("Função get")]

  # Prevents coffee script returning only the $get method
  return @
)

# Register the module the client's app must include from
reflinksModule = angular.module('reflinks', [])

# The 'reflinks' provider configures how the angular application
# interacts with reflinks.
reflinksModule.provider('reflinks', ->

  # Scope the user might set using the 'setScope' function.
  scope = {}

  # Scope that the contents of the page will be compiled against.
  @setScope = (_scope) -> scope = _scope

  @$get = () ->
    console.log("$get method")
)

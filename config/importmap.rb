# Importmap pins for the WrapItRuby engine.
# These get merged into the host app's importmap via the engine initializer.

pin_all_from WrapItRuby::Engine.root.join("app/javascript/wrap_it_ruby/controllers"),
  under: "controllers/wrap_it_ruby",
  to: "wrap_it_ruby/controllers"

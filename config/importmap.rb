# Importmap pins for the WrapItRuby engine.
# These get merged into the host app's importmap via the engine initializer.

pin_all_from WrapItRuby::Engine.root.join('app/javascript/wrap_it_ruby/controllers'),
             under: 'controllers/wrap_it_ruby',
             to: 'wrap_it_ruby/controllers'

# Sortable tree + request helpers
pin 'sortable-tree', to: 'https://esm.sh/sortable-tree@0.7.6'
pin '@rails/request.js', to: 'https://ga.jspm.io/npm:@rails/request.js@0.0.11/src/index.js'

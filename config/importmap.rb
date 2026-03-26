# Importmap pins for the WrapItRuby engine.
# These get merged into the host app's importmap via the engine initializer.

pin_all_from WrapItRuby::Engine.root.join('app/javascript/wrap_it_ruby/controllers'),
             under: 'controllers/wrap_it_ruby',
             to: 'wrap_it_ruby/controllers'

# Sortable tree + request helpers
pin 'sortable-tree', to: 'https://esm.sh/sortable-tree@0.7.6'
pin '@rails/request.js', to: 'https://ga.jspm.io/npm:@rails/request.js@0.0.11/src/index.js'

# Stimulus Sortable (drag-and-drop reordering)
pin 'sortablejs', to: 'https://ga.jspm.io/npm:sortablejs@1.15.6/modular/sortable.esm.js'
pin '@stimulus-components/sortable', to: 'https://ga.jspm.io/npm:@stimulus-components/sortable@5.0.1/dist/stimulus-sortable.mjs'

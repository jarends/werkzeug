class Chunk

    init: (@cfg) ->
        @cfg.registered = false
        data = detail:@cfg
        try e = new CustomEvent(@cfg.type, data)

        if not e
            e = document.createEvent 'CustomEvent'
            e.initCustomEvent @cfg.type, false, false, @cfg

        document.dispatchEvent e
        if not e.detail.registered
            console.log "Error registering chunk '#{@cfg.path}': ", e
        else
            console.log "#{if @cfg.chunk then 'chunk' else 'pack'} '#{@cfg.path}' registered"
        null

return new Chunk()

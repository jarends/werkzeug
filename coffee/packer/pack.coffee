class Pack

    init: (@cfg) ->
        @mainIndex = @cfg.startIndex
        @map       = {}
        @chunks    = {}
        @prepare()
        @start() if @cfg.total == 1
        null


    prepare: () ->
        console.log "packer: #{@cfg.path}, total packs: #{@cfg.total}"
        @startTime  = Date.now()
        @registered = 1
        pack        = @cfg.pack

        @getModule = (index, chunk) =>
            if chunk
                return @getChunk index, chunk

            m = @map[index]
            return m.exports if m

            m = @map[index] =
                require: @getModule
                exports: {}
            r = pack[index]
            if r
                try
                    r m, m.exports, m.require
                catch e
                    console.log "Error requiring '#{index}': ", e.stack
            else
                console.log "Error requiring '#{index}': module doesn't exist"
            m.exports

        document.addEventListener @cfg.type, (e) => @handleEvent(e)
        null


    getChunk: (index, chunk) ->
        chunks = @chunks[chunk]
        if @map[index]
            resolver = (clazz) =>
                new Promise((r) =>
                    m = @getModule index
                    if clazz
                        r(m[clazz])
                    else
                        r(m)
                    null)
        else
            if not chunks
                chunks     = @chunks[chunk] = []
                script     = document.createElement 'script'
                script.src = chunk
                document.body.appendChild script

            loader  = {}
            resolve = () =>
                console.log 'resolve promise: ', index
                clazz = loader.clazz
                m     = @getModule index
                if clazz
                    loader.r m[clazz]
                else
                    loader.r m

            loader.resolve = resolve
            chunks.push loader

            resolver = (clazz) ->
                loader.clazz = clazz
                new Promise((r) -> loader.r = r)
        resolver


    start: () ->
        setTimeout () =>
            t     = Date.now()
            @getModule @mainIndex
            now = Date.now()
            console.log "packer total startup in #{now - @startTime}ms, module initialization in #{now - t}ms."
            null
        null


    addPack: (pack) ->
        for key, value of pack
            if not @cfg.pack[key]
                @cfg.pack[key] = value
            else
                console.log "Error adding module: module '#{key}' already exists"
        null


    handleEvent: (e) ->
        detail = e.detail
        if detail
            detail.registered = true
            pack = detail.pack
            if pack
                console.log "add #{if detail.chunk then 'chunk' else 'pack'}: ", detail.path
                @addPack pack
            else
                console.log "Error adding pack: pack doesn't exists in details: ", detail
        else
            console.log "Error adding pack: detail doesn't exist in event: ", event

        chunk = detail.chunk
        if not chunk
            @mainIndex = detail.startIndex if detail.index == 0
            @start() if ++@registered == @cfg.total
        else
            chunks = @chunks[chunk]
            if chunks
                loader.resolve() for loader in chunks
        null


return new Pack()

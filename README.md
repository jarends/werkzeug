# werkzeug  
Is the german word for "tool".<br/>
And is the compiler and packer for my projects.<br/>
It does a little bit of the stuff, webpack and co. does for you.<br/>
It is simple in skills but easy to use and fast.

Werkzeug 
- compiles [typescript](https://www.typescriptlang.org/), [coffee](http://coffeescript.org/), [sass/scss](http://sass-lang.com/), [less](http://lesscss.org/) and [stylus](http://stylus-lang.com/)
- can copy all other assets
- packs your compiled code (if you use commonjs style modules) to bundles for use in browsers
- supports asynchronous chunks (angular 2/webpack style promisses)
- serves your stuff
- watches for changes and compiles and packs incremental
- creates sourcemaps for all compiled files and the bundles
- lints typescript
- has little support for angular projects
- and you can require json, css, html and txt files in your code, which will be inlined as strings
   
thats all. 
<br/>
<br/>
### Usage  

```coffee-script
    
    git clone https://github.com/jarends/werkzeug.git
    cd werkzeug
    npm link
    
    # compile, copy and pack once
    wz
    
    # start the watcher
    wz -w
    
```
&nbsp;
### Config
Werkzeug looks for a '.werkzeug' file in the current directory. The file can be a json file or a js, which exports a config object.
If no file was found, werkzeug looks in your user home for a config.

This is the default config with all implemented options:
('assets' is the copying process)

```coffee-script
      
    in:                      './src'                
    out:                     './.wz.tmp'            
        
    options:     
        includeExternalMaps: false # include source maps from node modules                 
        fffMaps:             false # inline source maps (fixes a firefox bug)                 
        
    server:                                            
        enabled:             true                   
        port:                3001 # if in use or blocked, the next free port is used                  
        
        
    coffee:                                         
        in:                  null                   
        out:                 null                   
        enabled:             true    
        
    ts:                                             
        in:                  null                   
        out:                 null                   
        enabled:             true    
        ngTool:              true # enable angular 2 magic   
        
    sass:                                           
        in:                  null                   
        out:                 null                   
        globals:             [] # files, which will compile, if others change                      
        enabled:             true    
        
    less:      
        in:                  null  
        out:                 null  
        enabled:             true    
        
    styl:                                           
        in:                  null                   
        out:                 null                   
        enabled:             true    
        
    assets:                                         
        in:                  null                   
        out:                 null                   
        enabled:             true    
        
    tslint:      
        ignoreInitial:       true # no linting on startup                   
        enabled:             true    
        
    packer:                                         
        nga:                 false # run ng-annotate (angular 1)                  
        bigChunks:           true  # pack multy requireds into chunks instead of bundles                 
        chunks:              './chunk_'      # file name prefix for chunk files       
        loaderPrefix:        'es6-promise!'  # prefix for requiring chunks       
        enabled:             true                  
        packages:            [] # in/out config for packing bundles                                    
          

# If no config can be found all files will be compiled 
# from the input dir './src' to the output dir './.wz.tmp'.
# So, you can easily start without any config, if you put your app in a src folder ;-)
          
          
# The simplest config, which compiles all files from './src' to './dist' 
# and packs the file './dist/main.js' (maybe compiled from './src/main.ts') 
# and all its required files to the bundle './dist/main.bundle.js'.
# The entry bundle must be the first (important!).

    out: './dist'
    packer:                      
        packages: [  
            in:  './main.js',                        
            out: './main.bundle.js'     
        ]


# Chunks will be handled automaticly if you use
chunkPromise = require('es6-promise!./my-external-module')()

# or for a specific export (required by angular 2)
chunkPromise = require('es6-promise!./my-external-module')('MyClass')

# and then
chunkPromise.then((result) -> console.log 'myExternalModuleOrClass: ', result)
            
            
# If you specify more than the entry bundle, you have to require all subsequent entry files.
# Otherwise they won't be activated.
# You also have to place src nodes for each bundle in your index.html             
```
   


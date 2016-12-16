# werkzeug  

Is the german word for "tool".  
And is the compiler and packer for my projects.  
It does a little bit of the stuff, [webpack](https://webpack.github.io/) and [co](http://browserify.org/). does for you.  
It is limited in its skills but easy to use and fast.  
  
What werkzeug does:   
- compiles [typescript](https://www.typescriptlang.org/), [coffee](http://coffeescript.org/), [sass/scss](http://sass-lang.com/), [less](http://lesscss.org/) and [stylus](http://stylus-lang.com/)
- can copy all other assets
- packs your compiled code (if you use commonjs style modules) to bundles for use in browsers
- supports asynchronous chunks (angular 2/webpack style promisses)
- serves your stuff
- watches for changes and compiles and packs incremental
- creates source maps for all compiled files and the bundles
- lints typescript
- has little support for [angular](https://angular.io/) projects
- and you can require json, css, html and txt files in your code, which will be inlined as strings  
     
And what it can't do: 
 
- the packer has no es2015 or es6 support (except for node_modules, but slow and only as fallback) (the ts compiler still can compile to es6)
- currently no AoT compiling for angular 2 (maybe i will work on this)
- no tree shaking (but i am interested)
- no pre or post processor or loader system, you can't pimp werkzeug (werkzeug will dispatch events soon, so you can utilize it by your own build process)
- no build or release process exists (i use googles [closure compiler](https://developers.google.com/closure/compiler/) to minify my bundles) (optimizing your project can be very special to your project and i like to keep werkzeug simple) 
&nbsp;    
  
### Usage
  
```coffee-script
    
    git clone https://github.com/jarends/werkzeug.git
    cd werkzeug
    npm install
    npm link
    
    # compile, copy and pack once
    wz
    
    # start the watcher, which also starts the server
    wz -w
    
    # example project angular 2 tour of heroes 
    # with werkzeug as build tool
    git clone https://github.com/jarends/angular2-tour-of-heroes-wz.git
    cd angular2-tour-of-heroes-wz
    npm install
    npm start # or wz -w
    
    
```
&nbsp;  
### Config

werkzeug looks for a '.werkzeug' file in the current directory.   
The file can be a json file or a js, which exports a config object.  
If no file was found, werkzeug looks in your user home for a config.  
  
This is the default config with all implemented options:  
('assets' is the copying process)  
```coffee-script
      
    in:                      './src'                
    out:                     './.wz.tmp'            
        
    options:     
        includeExternalMaps: false # include source maps from node_modules                 
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
        bigChunks:           true  # pack multi 'requireds' into chunks instead of bundles                 
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
&nbsp;    
### Some Details
#### ts and tslint
werkzeug comes with a default tsconfig.json and tslint.json.  
However, it also tries to read this files from your project directory so you can override the default settings.  
    
The creation and handling of source maps is a little bit tricky. That's why the following ts compiler options can't be overridden:
```coffee-script
options.sourceMap  # always true (will change, if source map creation can be turned off)
options.rootDir    # always the ts 'in' dir
options.outDir     # always the ts 'out' dir
options.sourceRoot # always the relative path from 'out' to 'in'
options.baseUrl    # always the path to werkzeugs node_modules    
```    
&nbsp;  
#### packer
The packer works on the compiled js files and parses all required dependencies.  
Currently only es5 commonjs style modules are supported.  
  
The parsing is done by a simple reqex for 'require' and that's the reason for a **MAJOR BUG** i still haven't fixed (for performance reasons):  
**If you have comments (single or multiline) in your code with unused but valid 'require' statements, this 'requires' are still parsed and the packer tries to import the dependencies.**  

The packer doesn't handle es6 files in your project, but he compiles required es6 node_modules with babel to not break your dependencies.  
The babel process isn't optimized and can slow down the whole packaging process if he is used excessively and the es6 detection is a little bit weird.
&nbsp;  
  
#### angular 2
Angular 2 has the ability to load templates and styles at runtime.
The [angular-cli](https://cli.angular.io/), which, by the way, does a very good job and i strongly recommend to use it,
replaces the 'templateUrl' and 'styleUrls' properties in the <code>@Component</code> decorator with the related 
'template' and 'styles' properties and embeds the files. 
 
I personally don't like this behaviour, because, if i want to embed my templates i can use 'template' instead of 'templateUrl', so i actively made a decision
and angular-cli ignores my decision (that's a little bit impolite).  
However, to not break projects, which expect this behaviour, i decided to enable the same impoliteness in werkzeug, but configurable ;-)
 
The second angular 2 magic is: replacing the routers 'loadChildren' list with the appropriate chunk promises.
&nbsp;  
  
#### possible bugs
- as i mentioned above: **out commented 'require' statements are parsed by the packer and the dependencies are packed**
- individual input and output directories per compiler aren't very well tested (especially in relation to source maps)
- input and output pointing to the same directory isn't very well tested (especially for the asset process) (**can corrupt your project, be careful!**)
- the asset process itself can behave a little bit weird in relation to what he copies
- the logic for when the linting happens must be reviewed and behaves sometimes strange
- the whole process can stuck in a loop (this can happen with errors in ts files and relies on the linting strangeness)
- (never tested on windows, sorry)    
&nbsp;  
  
### Motivation and Todos

When i started working with angular 2, SystemJS and webpack i was a little bit frustrated about the complexity of configuration and the time i spent to start new projects.  
The only thing i wanted to do was coding.    
The second point was the rapidly changing angular development in the release phase and the delay of webpack changes to manage all the new requirements.    
I wanted a little bit more control by my self, so i decided to build my own tool (it's a little bit maniac, looking at the multitude of other good tools, i know).  
  
werkzeug is currently not really meant to be ready. I stopped the development and started to use it so i can see, what more i have to do.   
There are still some ideas i want to implement.  
  
This are my current TODOS:    
```coffee-script
#TODO: add multiple in and out paths!!!

#TODO: add post processors (like autoprefixer)!!!

#TODO: fix errors for empty project!!!

#TODO: fix errors for multiple instances in the same project

#TODO: set ts.noEmitOnError = true and merge packer errors back to compiler errors???

#TODO: make source maps optional!!!

#TODO: enable cli flag for different configs, maybe run configs concurrently

#TODO: watch current wz config and restart app on change

#TODO: remember TREESHAKING for the build process (if it ever comes)???
```
&nbsp;  
  
### License

werkzeug is free and unencumbered public domain software. For more information, see http://unlicense.org/ or the accompanying UNLICENSE file.



   


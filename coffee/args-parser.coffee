require 'colors'

class ArgsParser


    constructor: () ->
        null


    parse: (@args, @cfg) ->
        @args.splice(0, 2) if @args
        @args   = @args or []
        @cmdCfg = {}
        @cmdMap = {}
        @cmds   = []
        @error  = null
        index   = 0

        @parseCmd cmd for cmd in @cfg.commands

        if not @cmdCfg['--help']
            @parseCmd
                name: 'help'
                help: 'shows the help'

        if @args.length == 0 and @cfg.defaultCmd
            @args.push '--' + @cfg.defaultCmd

        while index < @args.length
            arg = @args[index]
            cmd = @cmdCfg[arg]

            if cmd
                arg     = @args[index + 1]
                nextCmd = @cmdCfg[arg]
                if not arg or nextCmd
                    result =
                        name: cmd.name
                        arg:  cmd.arg?.default
                else
                    ++index
                    result =
                        name: cmd.name
                        arg:  arg

            else if arg
                if /^(--|-)/.test arg
                    @error = "unknown command \"#{arg}\"."
                    return @
                else if @args.length == 1
                    result = @getDefaultCmd(arg)
                else
                    @error = "unexpected argument \"#{arg}\"."
                    return @

            if result
                @cmds.push result
                @cmdMap[result.name] = result.arg

            ++index
        @


    parseCmd: (cmd) ->
        name          = cmd.name
        long          = '--' + name
        short         = '-'  + (cmd.short or name[0])
        cmd.long      = long
        cmd.short     = short
        @cmdCfg[long] = @cmdCfg[short] = cmd
        null


    getDefaultCmd: (arg) ->
        cmd = @cmdCfg['--' + @cfg.defaultCmd]
        if cmd
            result =
                name: cmd.name
                arg:  arg or cmd.arg?.default
        result


    chars: (char, count) ->
        new Array(count + 1).join(char)


    printHelp: () ->
        help = @cfg.help
        console.log '\n' + help + '\n' if help

        @printCommands()
        null


    printCommands: () ->
        sm = 0
        lg = 0
        for cmd in @cfg.commands
            sm = Math.max sm, cmd.short.length
            lg = Math.max lg, cmd.long.length

        console.log 'commands:\n'
        for cmd in @cfg.commands
            arg    = cmd.arg
            short  = cmd.short
            long   = cmd.long
            short  = short + ', ' + @chars ' ', sm - short.length
            long   = long        + @chars ' ', lg - long.length
            prefix = '    ' + short + long + '  '
            align  = prefix.length

            console.log prefix + cmd.help

            if arg
                help  = arg.help or 'one argument'
                value = arg.default
                if not value
                    console.log @chars(' ', align) + 'requires ' + help + '\n'
                else
                    console.log @chars(' ', align) + 'expects ' + help + ' as argument with "' + value + '" as default\n'
        console.log()
        null




module.exports = ArgsParser
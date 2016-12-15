loaderReg     = /(loadChildren\s*:\s*)('|")(.*?)#(.*?)('|")/gm
templateReg   = /(templateUrl)(\s*:\s*)('|")(.*?)('|")/gm
styleArrayReg = /(styleUrls)(\s*:\s*\[)((.|\r\n|\n)*?)(\])/g
styleReg      = /('|")(.*?)('|")/g




class NGTool

    @run: (path, text, cfg) ->
        text = text.replace loaderReg,   "$1() => require('#{cfg.packer.loaderPrefix}$3')('$4')"
        text = text.replace templateReg, "template$2require('$4')"
        text = text.replace styleArrayReg, (args...) ->
            list = args[3]
            list = list.replace styleReg, "require('$2')"
            'styles' + args[2] + list + args[5]
        text


module.exports = NGTool
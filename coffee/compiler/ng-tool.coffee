FS = require 'fs'
TS = require 'typescript'


unsupportedFileEncodingErrorCode = -2147024809


loaderReg     = /(loadChildren\s*:\s*)('|")(.*?)#(.*?)('|")/gm
templateReg   = /(templateUrl)(\s*:\s*)('|")(.*?)('|")/gm
styleArrayReg = /(styleUrls)(\s*:\s*\[)((.|\r\n|\n)*?)(\])/g
styleReg      = /('|")(.*?)('|")/g




class NGTool

    @run: (path, text, cfg) ->
        if loaderReg.test text
            replaced = true
        text = text.replace loaderReg,   "$1() => require('#{cfg.packer.loaderPrefix}$3')('$4')"
        text = text.replace templateReg, "template$2require('$4')"
        text = text.replace styleArrayReg, (args...) ->
            list = args[3]
            list = list.replace styleReg, "require('$2')"
            'styles' + args[2] + list + args[5]

        if replaced and false
            console.log 'replace loadChildren: ', path, '\n' + text
        text


module.exports = NGTool
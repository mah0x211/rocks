rockspec_format = "3.0"
package = "lexogram"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lexogram.git",
}
description = {
    summary = "grammar-driven lexical and syntactic analyzer that emits a lossless event array.",
    homepage = "https://github.com/mah0x211/lexogram",
    license = "MIT",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        ["lexogram"] = "lib/lexogram.lua",
        ["lexogram.analyzer"] = "lib/analyzer.lua",
        ["lexogram.check"] = "lib/check.lua",
        ["lexogram.compat"] = "lib/compat.lua",
        ["lexogram.compile"] = "lib/compile.lua",
        ["lexogram.compile.codegen"] = "lib/compile/codegen.lua",
        ["lexogram.compile.delimited"] = "lib/compile/delimited.lua",
        ["lexogram.compile.dfa"] = "lib/compile/dfa.lua",
        ["lexogram.compile.lexer"] = "lib/compile/lexer.lua",
        ["lexogram.compile.limits"] = "lib/compile/limits.lua",
        ["lexogram.compile.ll"] = "lib/compile/ll.lua",
        ["lexogram.compile.nfa"] = "lib/compile/nfa.lua",
        ["lexogram.compile.syntax"] = "lib/compile/syntax.lua",
        ["lexogram.compile.utf8range"] = "lib/compile/utf8range.lua",
        ["lexogram.events"] = "lib/events.lua",
        ["lexogram.extend"] = "lib/extend.lua",
        ["lexogram.grammar"] = "lib/grammar.lua",
        ["lexogram.grammars.bom_shebang"] = "grammars/bom_shebang.lua",
        ["lexogram.grammars.lua51"] = "grammars/lua51.lua",
        ["lexogram.grammars.lua51_shebang"] = "grammars/lua51_shebang.lua",
        ["lexogram.grammars.lua52"] = "grammars/lua52.lua",
        ["lexogram.grammars.lua52_shebang"] = "grammars/lua52_shebang.lua",
        ["lexogram.grammars.lua53"] = "grammars/lua53.lua",
        ["lexogram.grammars.lua53_shebang"] = "grammars/lua53_shebang.lua",
        ["lexogram.grammars.lua54"] = "grammars/lua54.lua",
        ["lexogram.grammars.lua54_shebang"] = "grammars/lua54_shebang.lua",
        ["lexogram.grammars.shebang"] = "grammars/shebang.lua",
        ["lexogram.loader"] = "lib/loader.lua",
        ["lexogram.pattern"] = "lib/pattern.lua",
        ["lexogram.source"] = "lib/source.lua",
        ["lexogram.text"] = "lib/text.lua",
        ["lexogram.tokenizer"] = "lib/tokenizer.lua",
        ["lexogram.utf8"] = "lib/utf8.lua",
        ["lexogram.version"] = "lib/version.lua",
    },
}

std = 'max'
include_files = {
    'context.lua',
    'test/*_test.lua',
}
ignore = {
    'assert',
    '212', -- Unused argument
    '311', -- Value assigned to a local variable is unused
}
